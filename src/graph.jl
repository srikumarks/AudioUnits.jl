# AVAudioEngine functionality for AUv3 - replacing AUGraph
#
# AUv3 uses AVAudioEngine instead of the legacy AUGraph.
# This module provides graph-like functionality using AVAudioEngine.
#
# Note: AVAudioEngine is primarily designed for realtime audio processing.
# Offline processing with it is Phase 8 work - currently this is a stub.

# AudioEngine is defined in types.jl
# Keep AudioGraph as an alias for backward compatibility
const AudioGraph = AudioEngine

# ============================================================================
# Constructor
# ============================================================================

"""
    AudioEngine()

Create a new AVAudioEngine for AUv3 audio graph management.

**Note:** Phase 8 work - currently a stub. Use AudioProcessor for
block-based offline processing instead.
"""
function AudioEngine()
    @warn "AVAudioEngine is Phase 8 work (not yet fully implemented for AUv3)"

    # Create AVAudioEngine
    engine = ObjectiveC.msgSend(
        AVAudioEngine,
        "alloc",
        ObjectiveC.Object
    )

    engine = ObjectiveC.msgSend(
        engine,
        "init",
        ObjectiveC.Object
    )

    if isnothing(engine) || engine == C_NULL
        error("Failed to create AVAudioEngine")
    end

    # Get the output node
    output_node = ObjectiveC.msgSend(
        engine,
        "outputNode",
        ObjectiveC.Object
    )

    return AudioEngine(engine, Dict{AudioUnit, Any}(), nothing, output_node, false, false)
end

# ============================================================================
# Node Management
# ============================================================================

"""
    addnode!(engine::AudioEngine, au::AudioUnit) -> Any

Add an AUv3 AudioUnit to the engine as a node.

**Note:** Phase 8 work - not yet fully implemented.
"""
function addnode!(engine::AudioEngine, au::AudioUnit)
    @warn "addnode! for AVAudioEngine is Phase 8 work (not yet fully implemented)"

    if isnothing(au.instance) || au.instance == C_NULL
        error("AudioUnit instance is null")
    end

    # Wrap AUAudioUnit in AVAudioUnit (AUv3)
    av_unit = ObjectiveC.msgSend(
        AVAudioUnit,
        "alloc",
        ObjectiveC.Object
    )

    av_unit = ObjectiveC.msgSend(
        av_unit,
        "initWithAudioUnit:",
        au.instance,
        ObjectiveC.Object
    )

    if isnothing(av_unit) || av_unit == C_NULL
        error("Failed to create AVAudioUnit from AUAudioUnit")
    end

    # Attach to engine
    error_ref = Ref{ObjectiveC.Object}(C_NULL)
    success = ObjectiveC.msgSend(
        engine.engine,
        "attachNode:error:",
        av_unit,
        error_ref,
        Bool
    )

    if !success
        err_desc = get_nserror_description(error_ref[])
        error("Failed to attach node to engine: $err_desc")
    end

    # Store node
    engine.nodes[au] = av_unit

    return av_unit
end

"""
    addoutputnode!(engine::AudioEngine) -> Any

Add a default audio output node to the engine.

**Note:** Phase 8 work - not yet fully implemented.
"""
function addoutputnode!(engine::AudioEngine)
    @warn "addoutputnode! for AVAudioEngine is Phase 8 work (not yet fully implemented)"
    return engine.output_node
end

# ============================================================================
# Connection
# ============================================================================

"""
    connect!(engine::AudioEngine, source_au::AudioUnit, dest_au::AudioUnit; kwargs...) -> Bool

Connect two AudioUnits in the engine.

**Note:** Phase 8 work - not yet fully implemented.
"""
function connect!(engine::AudioEngine, source_au::AudioUnit, dest_au::AudioUnit;
                  source_bus::UInt32=0, dest_bus::UInt32=0)
    @warn "connect! for AVAudioEngine is Phase 8 work (not yet fully implemented)"

    if !haskey(engine.nodes, source_au)
        error("Source AudioUnit not in engine")
    end
    if !haskey(engine.nodes, dest_au)
        error("Destination AudioUnit not in engine")
    end

    source_node = engine.nodes[source_au]
    dest_node = engine.nodes[dest_au]

    # Get format from source node
    format = ObjectiveC.msgSend(
        source_node,
        "outputFormatForBus:",
        source_bus,
        ObjectiveC.Object
    )

    if isnothing(format) || format == C_NULL
        error("Failed to get output format from source node")
    end

    # Connect nodes
    error_ref = Ref{ObjectiveC.Object}(C_NULL)
    success = ObjectiveC.msgSend(
        engine.engine,
        "connect:to:format:error:",
        source_node,
        dest_node,
        format,
        error_ref,
        Bool
    )

    if !success
        err_desc = get_nserror_description(error_ref[])
        error("Failed to connect nodes: $err_desc")
    end

    return true
end

# ============================================================================
# Graph Initialization
# ============================================================================

"""
    initializegraph!(engine::AudioEngine) -> Bool

Initialize the audio engine for processing.

**Note:** Phase 8 work - not yet fully implemented.
"""
function initializegraph!(engine::AudioEngine)
    @warn "initializegraph! for AVAudioEngine is Phase 8 work (not yet fully implemented)"

    if engine.initialized
        @warn "Engine already initialized"
        return true
    end

    error_ref = Ref{ObjectiveC.Object}(C_NULL)
    success = ObjectiveC.msgSend(
        engine.engine,
        "startAndReturnError:",
        error_ref,
        Bool
    )

    if !success
        err_desc = get_nserror_description(error_ref[])
        error("Failed to initialize engine: $err_desc")
    end

    engine.initialized = true
    return true
end

"""
    uninitializegraph!(engine::AudioEngine) -> Bool

Uninitialize the audio engine.

**Note:** Phase 8 work - not yet fully implemented.
"""
function uninitializegraph!(engine::AudioEngine)
    @warn "uninitializegraph! for AVAudioEngine is Phase 8 work (not yet fully implemented)"

    if !engine.initialized
        return true
    end

    if engine.running
        stopgraph!(engine)
    end

    ObjectiveC.msgSend(engine.engine, "stop")

    engine.initialized = false
    return true
end

# ============================================================================
# Realtime Mode
# ============================================================================

"""
    startgraph!(engine::AudioEngine) -> Bool

Start the audio engine running in realtime mode.

**Note:** Phase 8 work - not yet fully implemented.
"""
function startgraph!(engine::AudioEngine)
    @warn "startgraph! for AVAudioEngine is Phase 8 work (not yet fully implemented)"

    if !engine.initialized
        error("Engine must be initialized before starting")
    end

    if engine.running
        @warn "Engine already running"
        return true
    end

    error_ref = Ref{ObjectiveC.Object}(C_NULL)
    success = ObjectiveC.msgSend(
        engine.engine,
        "startAndReturnError:",
        error_ref,
        Bool
    )

    if !success
        err_desc = get_nserror_description(error_ref[])
        error("Failed to start engine: $err_desc")
    end

    engine.running = true
    return true
end

"""
    stopgraph!(engine::AudioEngine) -> Bool

Stop the audio engine from running.

**Note:** Phase 8 work - not yet fully implemented.
"""
function stopgraph!(engine::AudioEngine)
    @warn "stopgraph! for AVAudioEngine is Phase 8 work (not yet fully implemented)"

    if !engine.running
        return true
    end

    ObjectiveC.msgSend(engine.engine, "stop")

    engine.running = false
    return true
end

# ============================================================================
# Cleanup
# ============================================================================

"""
    disposegraph!(engine::AudioEngine) -> Bool

Dispose of the audio engine and free its resources.

**Note:** Phase 8 work - not yet fully implemented.
"""
function disposegraph!(engine::AudioEngine)
    @warn "disposegraph! for AVAudioEngine is Phase 8 work (not yet fully implemented)"

    if engine.running
        stopgraph!(engine)
    end

    if engine.initialized
        uninitializegraph!(engine)
    end

    engine.engine = nothing
    empty!(engine.nodes)

    return true
end

# ============================================================================
# Processing (Offline Mode)
# ============================================================================

"""
    processbuffer(engine::AudioEngine, au::AudioUnit, input) -> output

Process audio through an AudioUnit in the engine (offline mode).

**Note:** Phase 8 work - not fully implemented for AUv3.
Use AudioProcessor instead for reliable block-based offline processing.
"""
function processbuffer(engine::AudioEngine, au::AudioUnit, input)
    @warn "processbuffer for AVAudioEngine is Phase 8 work - use AudioProcessor instead"
    error("AVAudioEngine offline processing not yet implemented for AUv3")
end

"""
    processbuffer(au::AudioUnit, input) -> output

Process audio through a standalone AudioUnit (offline mode).

**Note:** For AUv3, use AudioProcessor for reliable block-based processing.
"""
function processbuffer(au::AudioUnit, input)
    @warn "processbuffer for offline processing with AudioUnits - use AudioProcessor instead for AUv3"
    error("AudioUnit offline processing not yet implemented for AUv3")
end

"""
    processbuffer!(output, engine::AudioEngine, au::AudioUnit, input) -> output

Process audio in-place through an AudioUnit in the engine.

**Note:** Phase 8 work - use AudioProcessor instead for AUv3.
"""
function processbuffer!(output, engine::AudioEngine, au::AudioUnit, input)
    @warn "processbuffer! for AVAudioEngine is Phase 8 work - use AudioProcessor instead"
    error("AVAudioEngine offline processing not yet implemented for AUv3")
end

"""
    process!(au::AudioUnit, input, output) -> output

Process audio through a standalone AudioUnit in-place.

**Note:** For AUv3, use AudioProcessor for reliable block-based processing.
"""
function process!(au::AudioUnit, input, output)
    @warn "process! for offline processing - use AudioProcessor instead for AUv3"
    error("AudioUnit offline processing not yet implemented for AUv3")
end
