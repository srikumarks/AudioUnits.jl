**NOTE**:  This project is mostly generated through interactions with Claude Code.
The history files are included in `claude/` for reference and future work.

# AudioUnits.jl

A Julia package for interfacing with macOS AudioUnits, providing access to audio effects processors and music synthesis devices.

## Overview

AudioUnits.jl wraps the macOS AudioToolbox framework, enabling Julia programs to:

- Discover and enumerate available AudioUnits on the system
- Load AudioUnits by name or identifier
- Query AudioUnit capabilities (effects processing, MIDI input)
- Access and manipulate AudioUnit parameters
- Retrieve comprehensive documentation about AudioUnits

This package provides a synchronous, programmatic API without GUI requirements.

## Features

- **AudioUnit Discovery**: Find all AudioUnits or filter by type (effects, instruments, etc.)
- **Parameter Management**: Get/set parameter values with full metadata (ranges, units, defaults)
- **MIDI Support**: Send MIDI messages to music device AudioUnits (Note On/Off, Control Change, Program Change, etc.)
- **Audio Graph (AUGraph)**: Connect AudioUnits in processing chains with two modes:
  - **Realtime mode**: Automatic hardware I/O with continuous audio processing
  - **Driven mode**: Synchronous buffer processing with SampleBuf support
- **Capability Detection**: Determine if a unit supports effects processing or MIDI input
- **Stream Format Queries**: Retrieve audio format specifications and channel configurations
- **Documentation Generation**: Automatically generate formatted documentation for any AudioUnit
- **Rich Display Support**: Beautiful text and HTML displays for terminal and Jupyter notebooks
- **Bypass Mode**: Enable/disable effect bypass where supported
- **Latency Information**: Query processing latency and tail time

## Requirements

- macOS (AudioUnits are a macOS-specific technology)
- Julia 1.6 or later

**Cross-Platform Note:** The package can be imported on any platform, but AudioUnit functionality is only available on macOS. Use `issupported()` to check platform support at runtime.

## Installation

```julia
# In development - will be registered in Julia package registry
using Pkg
Pkg.add(url="https://github.com/yourusername/AudioUnits.jl")
```

## Quick Start

```julia
using AudioUnits

# Check platform support
if !issupported()
    error("AudioUnits are only supported on macOS")
end

# List all available AudioUnits
all_units = findaudiounits()
println("Found ", length(all_units), " AudioUnits")

# Find only effect processors
effects = findaudiounits(kAudioUnitType_Effect)

# Find music devices (instruments)
instruments = findaudiounits(kAudioUnitType_MusicDevice)

# Load a specific AudioUnit by name
au = load("AULowpass")

# Initialize it for use
initialize(au)

# Get all parameters
params = parameters(au)

# Get detailed information
info_summary = info(au)
println("AudioUnit: ", info_summary.name, " v", join(info_summary.version, "."))
println("Parameters: ", info_summary.parameter_count)

# Set a parameter value
if !isempty(params)
    param = params[1]
    setparametervalue!(au, param.id, 0.5)
    current = parametervalue(au, param.id)
    println("Parameter value: ", current)
end

# Generate comprehensive documentation
doc = documentation(au)
println(doc)

# Clean up
uninitialize(au)
dispose(au)
```

## Display in Terminal and Jupyter Notebooks

AudioUnits.jl provides rich display functionality for both terminal (REPL) and Jupyter notebooks:

### Terminal Display

```julia
using AudioUnits

au = load("AULowpass")
initialize(au)

# Display automatically formats for terminal
display(au)
```

Displays a formatted box with:
- AudioUnit name and status
- Basic information (manufacturer, type, version)
- Capabilities with checkmarks (✓/✗)
- Channel configurations
- Performance metrics (latency, tail time)
- Parameter summary

### Jupyter Notebook Display

In Jupyter notebooks, objects are automatically rendered with beautiful HTML formatting:

```julia
# In a Jupyter notebook cell
au = load("AULowpass")
initialize(au)
au  # Displays with rich HTML formatting
```

Features:
- Color-coded status badges
- Two-column grid layout
- Scrollable parameter tables
- Professional styling with inline CSS

### Display Parameters

```julia
params = parameters(au)
display(params[1])  # Shows parameter details
```

See `examples/display_demo.jl` and `examples/notebook_example.md` for more details.

## Audio Graph (AUGraph)

AudioUnits.jl provides full support for creating and managing Audio Unit Graphs, which allow you to connect multiple AudioUnits together in processing chains.

### Realtime Mode

In realtime mode, the graph automatically processes audio and outputs to hardware:

```julia
using AudioUnits

# Create graph
graph = AudioGraph()

# Load instrument
au = load("DLSMusicDevice")
music_node = addnode!(graph, au)

# Add output for hardware
output_node = addoutputnode!(graph)

# Connect nodes
connect!(graph, music_node, output_node)

# Initialize and start
initializegraph!(graph)
initialize(au)
startgraph!(graph)

# Play MIDI - you'll hear it in realtime!
noteon(au, 60, 100)
sleep(2.0)
noteoff(au, 60)

# Stop and clean up
stopgraph!(graph)
uninitialize(au)
disposegraph!(graph)
```

### Driven Mode (Offline Processing)

In driven mode, you provide input buffers and get processed output synchronously. This works with **any buffer size**, including small buffers (64, 128 samples) for low-latency streaming:

```julia
using AudioUnits
using SampledSignals

# Load effect
au = load("AULowpass")
initialize(au)

# Process with any buffer size - large buffers for batch processing
input_large = SampleBuf(randn(Float32, 2, 44100), 44100)
output_large = processbuffer(au, input_large)

# Or small buffers for streaming (64, 128, 256 samples)
input_small = SampleBuf(randn(Float32, 2, 128), 44100)
output_small = processbuffer(au, input_small)

# Process multiple small buffers in sequence - state is maintained
for i in 1:100
    chunk = SampleBuf(randn(Float32, 2, 128), 44100)
    processed = processbuffer(au, chunk)
    # ... use processed audio
end

# Zero-allocation streaming with processbuffer! (in-place)
# Pre-allocate buffers once for maximum performance
input = SampleBuf(zeros(Float32, 2, 128), 44100)
output = SampleBuf(zeros(Float32, 2, 128), 44100)

for i in 1:1000
    input.data .= randn(Float32, 2, 128)  # Fill with new data
    processbuffer!(output, au, input)      # No allocation!
    # ... use output
end

# Clean up
uninitialize(au)
dispose(au)
```

The driven mode is perfect for:
- **Streaming processing**: Small buffers (64-128 samples) for low-latency applications
- **Batch processing**: Large buffers for processing entire audio files
- **Audio analysis**: Any buffer size for visualization and feature extraction
- **Non-realtime rendering**: Precise offline processing
- **Automated testing**: Predictable, synchronous processing

See `examples/realtime_graph.jl`, `examples/driven_graph.jl`, and `examples/streaming_example.jl` for detailed examples.

## API Reference

### Platform Support

```julia
issupported() -> Bool
```
Check whether AudioUnits are supported on the current platform. Returns `true` on macOS, `false` otherwise.

### AudioUnit Discovery

```julia
findaudiounits([type]) -> Vector{AudioUnitInfo}
```
Find all AudioUnits, optionally filtered by type.

```julia
listall(; type=nothing) -> String
```
Get a formatted list of all available AudioUnits.

### AudioUnit Loading and Management

```julia
load(name::String) -> AudioUnit
load(type::AudioUnitType, subtype::UInt32) -> AudioUnit
```
Load an AudioUnit by name or type/subtype identifier.

```julia
initialize(au::AudioUnit) -> Bool
uninitialize(au::AudioUnit) -> Bool
dispose(au::AudioUnit)
```
Initialize, uninitialize, and dispose of AudioUnit instances.

### Parameter Management

```julia
parameters(au::AudioUnit; scope=kAudioUnitScope_Global) -> Vector{AudioUnitParameter}
```
Get all parameters for an AudioUnit.

```julia
parameterinfo(au::AudioUnit, param_id::UInt32, scope=kAudioUnitScope_Global) -> AudioUnitParameterInfo
```
Get detailed information about a specific parameter.

```julia
parametervalue(au::AudioUnit, param_id::UInt32; scope, element) -> Float32
setparametervalue!(au::AudioUnit, param_id::UInt32, value::Real; scope, element) -> Bool
```
Get or set parameter values.

### Capability Detection

```julia
supportseffects(au::AudioUnit) -> Bool
supportsmidi(au::AudioUnit) -> Bool
canbypass(au::AudioUnit) -> Bool
```
Check AudioUnit capabilities.

```julia
channelcapabilities(au::AudioUnit) -> Vector{ChannelConfiguration}
streamformat(au::AudioUnit; scope, element) -> StreamFormat
latency(au::AudioUnit) -> Float64
tailtime(au::AudioUnit) -> Float64
```
Query processing characteristics.

```julia
setbypass!(au::AudioUnit, bypass::Bool) -> Bool
```
Enable or disable effect bypass.

### MIDI Functions

```julia
sendmidi(au::AudioUnit, status::UInt8, data1::UInt8, data2::UInt8) -> Bool
```
Send a raw MIDI event to a music device AudioUnit.

```julia
noteon(au::AudioUnit, note::Integer, velocity::Integer=100; channel::Integer=0) -> Bool
noteoff(au::AudioUnit, note::Integer; channel::Integer=0) -> Bool
```
Send MIDI Note On/Off messages.

```julia
controlchange(au::AudioUnit, controller::Integer, value::Integer; channel::Integer=0) -> Bool
programchange(au::AudioUnit, program::Integer; channel::Integer=0) -> Bool
pitchbend(au::AudioUnit, value::Integer; channel::Integer=0) -> Bool
```
Send MIDI Control Change, Program Change, and Pitch Bend messages.

```julia
allnotesoff(au::AudioUnit; channel::Integer=0) -> Bool
```
Turn off all notes on a MIDI channel.

### Audio Graph Functions

```julia
AudioGraph() -> AudioGraph
```
Create a new Audio Unit Graph.

```julia
addnode!(graph::AudioGraph, au::AudioUnit) -> Int32
addoutputnode!(graph::AudioGraph) -> Int32
```
Add AudioUnit or output nodes to the graph. Returns node ID.

```julia
connect!(graph::AudioGraph, source_node::Int32, dest_node::Int32; source_bus=0, dest_bus=0) -> Bool
```
Connect two nodes in the graph.

```julia
initializegraph!(graph::AudioGraph) -> Bool
uninitializegraph!(graph::AudioGraph) -> Bool
disposegraph!(graph::AudioGraph) -> Bool
```
Initialize, uninitialize, and dispose of graphs.

```julia
startgraph!(graph::AudioGraph) -> Bool
stopgraph!(graph::AudioGraph) -> Bool
```
Start and stop realtime audio processing.

```julia
processbuffer(graph::AudioGraph, node::Int32, input::SampleBuf) -> SampleBuf
processbuffer(au::AudioUnit, input::SampleBuf) -> SampleBuf
```
Process audio through a graph node or standalone AudioUnit in driven mode.

```julia
processbuffer!(output::SampleBuf, graph::AudioGraph, node::Int32, input::SampleBuf) -> SampleBuf
processbuffer!(output::SampleBuf, au::AudioUnit, input::SampleBuf) -> SampleBuf
```
In-place processing that writes to a pre-allocated output buffer. Eliminates allocations for high-performance streaming.

### Documentation

```julia
documentation(au::AudioUnit) -> String
info(au::AudioUnit) -> AudioUnitSummary
```
Retrieve formatted documentation and structured information.

## AudioUnit Types

The package defines the following AudioUnit type constants:

- `kAudioUnitType_Effect` - Audio effects processors
- `kAudioUnitType_MusicDevice` - Music synthesis devices (instruments)
- `kAudioUnitType_MusicEffect` - Music-specific effects
- `kAudioUnitType_FormatConverter` - Format conversion units
- `kAudioUnitType_Mixer` - Audio mixers
- `kAudioUnitType_Panner` - Panning effects
- `kAudioUnitType_Generator` - Audio generators
- `kAudioUnitType_OfflineEffect` - Offline processing effects

## Examples

See the `examples/` directory for detailed usage examples:

- `basic_usage.jl` - Introduction to basic AudioUnit operations
- `advanced_usage.jl` - Advanced features including parameter manipulation and capability detection
- `simple_midi.jl` - Quick start guide for sending MIDI messages to music devices
- `midi_example.jl` - Comprehensive MIDI functionality demonstration with DLSMusicDevice
- `realtime_graph.jl` - Realtime audio processing with AUGraph and hardware I/O
- `driven_graph.jl` - Offline/driven audio processing with SampleBuf
- `streaming_example.jl` - Small buffer streaming (64, 128 samples) for low-latency processing
- `display_demo.jl` - Demonstration of display functionality for terminal and Jupyter
- `notebook_example.md` - Guide for using AudioUnits.jl in Jupyter notebooks with HTML rendering

## Architecture

The package uses Julia's `ccall` interface to communicate with the macOS AudioToolbox framework. Key components:

- `types.jl` - Type definitions and constants
- `core.jl` - AudioUnit discovery, loading, and lifecycle management
- `parameters.jl` - Parameter querying and manipulation
- `capabilities.jl` - Capability detection and stream format queries
- `documentation.jl` - Documentation generation and formatting
- `display.jl` - Base.show implementations for terminal and Jupyter notebook display
- `midi.jl` - MIDI message sending functionality for music device AudioUnits
- `graph.jl` - AUGraph support for realtime and driven audio processing
- `api.jl` - Public API with Julia naming conventions

## Notes

- AudioUnits must be initialized before most operations (except parameter queries)
- Always dispose of AudioUnits when done to free system resources
- Some parameters may be read-only or have special constraints
- Not all AudioUnits support all features (bypass, MIDI, etc.)
- **Audio I/O**: For realtime audio output, use `AudioGraph` to connect AudioUnits to hardware I/O
- **Buffer Processing**: `processbuffer()` expects stereo `SampleBuf{T, 2}` (channels × samples format)

## License

This package is provided as-is. Check the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.
