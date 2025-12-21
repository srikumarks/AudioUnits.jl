# AUGraph functionality for connecting and processing AudioUnits

using SampledSignals

"""
    AudioGraph

Represents an Audio Unit Graph (AUGraph) for connecting and processing AudioUnits.

An AudioGraph can operate in two modes:
1. **Realtime mode**: Automatically processes audio through connected AudioUnits with hardware I/O
2. **Driven mode**: Synchronously processes audio buffers provided by the client

# Fields
- `graph::Ptr{Cvoid}`: Pointer to the underlying AUGraph
- `nodes::Dict{AudioUnit, Int32}`: Map of AudioUnits to their node IDs in the graph
- `initialized::Bool`: Whether the graph has been initialized
- `running::Bool`: Whether the graph is currently running (realtime mode)
"""
mutable struct AudioGraph
    graph::Ptr{Cvoid}
    nodes::Dict{AudioUnit, Int32}
    output_node::Int32
    initialized::Bool
    running::Bool

    function AudioGraph()
        graph_ref = Ref{Ptr{Cvoid}}()
        status = ccall((:NewAUGraph, AudioToolbox), Int32, (Ptr{Ptr{Cvoid}},), graph_ref)

        if status != noErr
            error("Failed to create AUGraph: OSStatus $status")
        end

        new(graph_ref[], Dict{AudioUnit, Int32}(), -1, false, false)
    end
end

"""
    addnode!(graph::AudioGraph, au::AudioUnit) -> Int32

Add an AudioUnit to the graph and return its node ID.

# Examples
```julia
graph = AudioGraph()
au = load("AULowpass")
node_id = addnode!(graph, au)
```
"""
function addnode!(graph::AudioGraph, au::AudioUnit)
    # Create AudioComponentDescription for the node
    desc = AudioComponentDescription(
        UInt32(au.au_type),
        au.subtype,
        0,  # manufacturer (0 = any)
        0,  # flags
        0   # flags mask
    )

    node_ref = Ref{Int32}()
    status = ccall((:AUGraphAddNode, AudioToolbox), Int32,
                  (Ptr{Cvoid}, Ref{AudioComponentDescription}, Ptr{Int32}),
                  graph.graph, Ref(desc), node_ref)

    if status != noErr
        error("Failed to add node to graph: OSStatus $status")
    end

    node_id = node_ref[]
    graph.nodes[au] = node_id

    # Get the AudioUnit instance from the node
    au_ref = Ref{Ptr{Cvoid}}()
    status = ccall((:AUGraphNodeInfo, AudioToolbox), Int32,
                  (Ptr{Cvoid}, Int32, Ptr{Cvoid}, Ptr{Ptr{Cvoid}}),
                  graph.graph, node_id, C_NULL, au_ref)

    if status != noErr
        error("Failed to get AudioUnit from node: OSStatus $status")
    end

    # Update the AudioUnit's instance pointer
    au.instance = au_ref[]

    return node_id
end

"""
    addoutputnode!(graph::AudioGraph) -> Int32

Add a default audio output node to the graph for realtime mode.

# Examples
```julia
graph = AudioGraph()
output_id = addoutputnode!(graph)
```
"""
function addoutputnode!(graph::AudioGraph)
    # kAudioUnitType_Output, kAudioUnitSubType_DefaultOutput
    desc = AudioComponentDescription(
        0x61756f75,  # 'auou' - kAudioUnitType_Output
        0x64656620,  # 'def ' - kAudioUnitSubType_DefaultOutput
        0,
        0,
        0
    )

    node_ref = Ref{Int32}()
    status = ccall((:AUGraphAddNode, AudioToolbox), Int32,
                  (Ptr{Cvoid}, Ref{AudioComponentDescription}, Ptr{Int32}),
                  graph.graph, Ref(desc), node_ref)

    if status != noErr
        error("Failed to add output node: OSStatus $status")
    end

    graph.output_node = node_ref[]
    return node_ref[]
end

"""
    connect!(graph::AudioGraph, source_node::Int32, dest_node::Int32;
             source_bus::UInt32=0, dest_bus::UInt32=0)

Connect two nodes in the graph.

# Arguments
- `graph::AudioGraph`: The graph containing the nodes
- `source_node::Int32`: Source node ID
- `dest_node::Int32`: Destination node ID
- `source_bus::UInt32`: Output bus of source (default: 0)
- `dest_bus::UInt32`: Input bus of destination (default: 0)

# Examples
```julia
connect!(graph, node1, node2)
connect!(graph, node1, node2, source_bus=0, dest_bus=1)
```
"""
function connect!(graph::AudioGraph, source_node::Int32, dest_node::Int32;
                  source_bus::UInt32=UInt32(0), dest_bus::UInt32=UInt32(0))
    status = ccall((:AUGraphConnectNodeInput, AudioToolbox), Int32,
                  (Ptr{Cvoid}, Int32, UInt32, Int32, UInt32),
                  graph.graph, source_node, source_bus, dest_node, dest_bus)

    if status != noErr
        error("Failed to connect nodes: OSStatus $status")
    end

    return true
end

"""
    initializegraph!(graph::AudioGraph)

Initialize the graph, preparing all nodes for processing.

# Examples
```julia
initializegraph!(graph)
```
"""
function initializegraph!(graph::AudioGraph)
    if graph.initialized
        @warn "Graph already initialized"
        return true
    end

    status = ccall((:AUGraphInitialize, AudioToolbox), Int32,
                  (Ptr{Cvoid},), graph.graph)

    if status != noErr
        error("Failed to initialize graph: OSStatus $status")
    end

    graph.initialized = true
    return true
end

"""
    uninitializegraph!(graph::AudioGraph)

Uninitialize the graph.

# Examples
```julia
uninitializegraph!(graph)
```
"""
function uninitializegraph!(graph::AudioGraph)
    if !graph.initialized
        return true
    end

    if graph.running
        stopgraph!(graph)
    end

    status = ccall((:AUGraphUninitialize, AudioToolbox), Int32,
                  (Ptr{Cvoid},), graph.graph)

    if status != noErr
        error("Failed to uninitialize graph: OSStatus $status")
    end

    graph.initialized = false
    return true
end

"""
    disposegraph!(graph::AudioGraph)

Dispose of the graph and free its resources.

# Examples
```julia
disposegraph!(graph)
```
"""
function disposegraph!(graph::AudioGraph)
    if graph.running
        stopgraph!(graph)
    end

    if graph.initialized
        uninitializegraph!(graph)
    end

    status = ccall((:DisposeAUGraph, AudioToolbox), Int32,
                  (Ptr{Cvoid},), graph.graph)

    if status != noErr
        @warn "Failed to dispose graph: OSStatus $status"
    end

    graph.graph = C_NULL
    empty!(graph.nodes)

    return true
end

# ==============================================================================
# Realtime Mode
# ==============================================================================

"""
    startgraph!(graph::AudioGraph)

Start the graph running in realtime mode.

The graph will automatically pull audio through the connected AudioUnits
and output to the hardware audio device.

# Examples
```julia
graph = AudioGraph()
au = load("DLSMusicDevice")
node = addnode!(graph, au)
output = addoutputnode!(graph)
connect!(graph, node, output)
initializegraph!(graph)

# Start realtime processing
startgraph!(graph)

# Send MIDI to make sound
initialize(au)
noteon(au, 60, 100)
sleep(2.0)
noteoff(au, 60)

# Stop when done
stopgraph!(graph)
```
"""
function startgraph!(graph::AudioGraph)
    if !graph.initialized
        error("Graph must be initialized before starting")
    end

    if graph.running
        @warn "Graph already running"
        return true
    end

    status = ccall((:AUGraphStart, AudioToolbox), Int32,
                  (Ptr{Cvoid},), graph.graph)

    if status != noErr
        error("Failed to start graph: OSStatus $status")
    end

    graph.running = true
    return true
end

"""
    stopgraph!(graph::AudioGraph)

Stop the graph from running in realtime mode.

# Examples
```julia
stopgraph!(graph)
```
"""
function stopgraph!(graph::AudioGraph)
    if !graph.running
        return true
    end

    status = ccall((:AUGraphStop, AudioToolbox), Int32,
                  (Ptr{Cvoid},), graph.graph)

    if status != noErr
        error("Failed to stop graph: OSStatus $status")
    end

    graph.running = false
    return true
end

# ==============================================================================
# Driven Mode (Offline Rendering)
# ==============================================================================

"""
    processbuffer(graph::AudioGraph, node::Int32, input::SampleBuf{T, 2}) -> SampleBuf{T, 2} where T

Process audio through a specific node in the graph using provided input.

This is the driven/offline mode where you provide input samples and get output samples.

# Arguments
- `graph::AudioGraph`: The graph containing the node
- `node::Int32`: The node ID to render
- `input::SampleBuf`: Input audio buffer (channels × samples)

# Returns
- `SampleBuf`: Processed output audio buffer

# Examples
```julia
using SampledSignals

# Create graph and add effect
graph = AudioGraph()
au = load("AULowpass")
initialize(au)
node = addnode!(graph, au)
initializegraph!(graph)

# Process audio
sr = 44100
input = SampleBuf(randn(Float32, 2, sr), sr)  # 1 second of stereo noise
output = processbuffer(graph, node, input)
```
"""
function processbuffer(graph::AudioGraph, node::Int32, input::SampleBuf{T, 2}) where T
    if !graph.initialized
        error("Graph must be initialized before processing")
    end

    # Get the AudioUnit from the node
    au_ref = Ref{Ptr{Cvoid}}()
    status = ccall((:AUGraphNodeInfo, AudioToolbox), Int32,
                  (Ptr{Cvoid}, Int32, Ptr{Cvoid}, Ptr{Ptr{Cvoid}}),
                  graph.graph, node, C_NULL, au_ref)

    if status != noErr
        error("Failed to get AudioUnit from node: OSStatus $status")
    end

    au_instance = au_ref[]

    # Get input dimensions
    nchannels = size(input, 1)
    nframes = size(input, 2)
    samplerate = Float64(input.samplerate)

    # Create output buffer
    output_data = zeros(T, nchannels, nframes)

    # Convert input to interleaved format if needed
    # AudioUnits expect non-interleaved (planar) format
    input_data = collect(input.data)  # Ensure it's a regular array

    # Create AudioBufferList structure
    # struct AudioBufferList {
    #     UInt32 mNumberBuffers;
    #     AudioBuffer mBuffers[1];  // Variable length
    # }
    # struct AudioBuffer {
    #     UInt32 mNumberChannels;
    #     UInt32 mDataByteSize;
    #     void* mData;
    # }

    buffer_list_size = 4 + nchannels * (4 + 4 + sizeof(Ptr{Cvoid}))
    input_buffer_list = zeros(UInt8, buffer_list_size)
    output_buffer_list = zeros(UInt8, buffer_list_size)

    # Set number of buffers (one per channel for non-interleaved)
    unsafe_store!(Ptr{UInt32}(pointer(input_buffer_list)), UInt32(nchannels))
    unsafe_store!(Ptr{UInt32}(pointer(output_buffer_list)), UInt32(nchannels))

    # Set up each buffer
    for ch in 1:nchannels
        offset = 4 + (ch - 1) * (4 + 4 + sizeof(Ptr{Cvoid}))

        # Input buffer
        unsafe_store!(Ptr{UInt32}(pointer(input_buffer_list) + offset), UInt32(1))  # mNumberChannels
        unsafe_store!(Ptr{UInt32}(pointer(input_buffer_list) + offset + 4), UInt32(nframes * sizeof(T)))  # mDataByteSize
        channel_data = view(input_data, ch, :)
        unsafe_store!(Ptr{Ptr{Cvoid}}(pointer(input_buffer_list) + offset + 8), pointer(channel_data))  # mData

        # Output buffer
        unsafe_store!(Ptr{UInt32}(pointer(output_buffer_list) + offset), UInt32(1))
        unsafe_store!(Ptr{UInt32}(pointer(output_buffer_list) + offset + 4), UInt32(nframes * sizeof(T)))
        channel_out = view(output_data, ch, :)
        unsafe_store!(Ptr{Ptr{Cvoid}}(pointer(output_buffer_list) + offset + 8), pointer(channel_out))
    end

    # Set up AudioTimeStamp
    # For offline rendering, we can use a simple incrementing sample time
    timestamp = zeros(UInt8, 80)  # Size of AudioTimeStamp struct
    # Set mSampleTime
    unsafe_store!(Ptr{Float64}(pointer(timestamp)), 0.0)
    # Set mFlags to indicate sample time is valid
    unsafe_store!(Ptr{UInt32}(pointer(timestamp) + 8), UInt32(1))

    # Render the audio
    # OSStatus AudioUnitRender(AudioUnit inUnit,
    #                         AudioUnitRenderActionFlags *ioActionFlags,
    #                         const AudioTimeStamp *inTimeStamp,
    #                         UInt32 inOutputBusNumber,
    #                         UInt32 inNumberFrames,
    #                         AudioBufferList *ioData)

    action_flags = Ref{UInt32}(0)
    status = ccall((:AudioUnitRender, AudioToolbox), Int32,
                  (Ptr{Cvoid}, Ptr{UInt32}, Ptr{UInt8}, UInt32, UInt32, Ptr{UInt8}),
                  au_instance, action_flags, timestamp, UInt32(0), UInt32(nframes), output_buffer_list)

    if status != noErr
        error("Failed to render audio: OSStatus $status")
    end

    # Create output SampleBuf
    return SampleBuf(output_data, samplerate)
end

"""
    processbuffer(au::AudioUnit, input::SampleBuf{T, 2}) -> SampleBuf{T, 2} where T

Process audio through a standalone AudioUnit (without a graph).

This is a convenience function for processing audio through a single AudioUnit
without needing to set up a full graph.

# Arguments
- `au::AudioUnit`: The AudioUnit to process through
- `input::SampleBuf`: Input audio buffer

# Returns
- `SampleBuf`: Processed output audio buffer

# Examples
```julia
using SampledSignals

au = load("AULowpass")
initialize(au)

# Set some parameters
params = parameters(au)
if !isempty(params)
    setparametervalue!(au, params[1].id, 0.3)
end

# Process audio
input = SampleBuf(randn(Float32, 2, 44100), 44100)
output = processbuffer(au, input)
```
"""
function processbuffer(au::AudioUnit, input::SampleBuf{T, 2}) where T
    if !au.initialized
        error("AudioUnit must be initialized before processing")
    end

    # Process directly without a graph
    nchannels = size(input, 1)
    nframes = size(input, 2)
    samplerate = Float64(input.samplerate)

    input_data = collect(input.data)
    output_data = zeros(T, nchannels, nframes)

    # Create AudioBufferList
    buffer_list_size = 4 + nchannels * (4 + 4 + sizeof(Ptr{Cvoid}))
    output_buffer_list = zeros(UInt8, buffer_list_size)

    unsafe_store!(Ptr{UInt32}(pointer(output_buffer_list)), UInt32(nchannels))

    for ch in 1:nchannels
        offset = 4 + (ch - 1) * (4 + 4 + sizeof(Ptr{Cvoid}))
        unsafe_store!(Ptr{UInt32}(pointer(output_buffer_list) + offset), UInt32(1))
        unsafe_store!(Ptr{UInt32}(pointer(output_buffer_list) + offset + 4), UInt32(nframes * sizeof(T)))
        channel_out = view(output_data, ch, :)
        unsafe_store!(Ptr{Ptr{Cvoid}}(pointer(output_buffer_list) + offset + 8), pointer(channel_out))
    end

    # Simple timestamp
    timestamp = zeros(UInt8, 80)
    unsafe_store!(Ptr{Float64}(pointer(timestamp)), 0.0)
    unsafe_store!(Ptr{UInt32}(pointer(timestamp) + 8), UInt32(1))

    action_flags = Ref{UInt32}(0)
    status = ccall((:AudioUnitRender, AudioToolbox), Int32,
                  (Ptr{Cvoid}, Ptr{UInt32}, Ptr{UInt8}, UInt32, UInt32, Ptr{UInt8}),
                  au.instance, action_flags, timestamp, UInt32(0), UInt32(nframes), output_buffer_list)

    if status != noErr
        error("Failed to render audio: OSStatus $status")
    end

    return SampleBuf(output_data, samplerate)
end
