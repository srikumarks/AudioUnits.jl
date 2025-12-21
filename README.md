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
- **Capability Detection**: Determine if a unit supports effects processing or MIDI input
- **Stream Format Queries**: Retrieve audio format specifications and channel configurations
- **Documentation Generation**: Automatically generate formatted documentation for any AudioUnit
- **Rich Display Support**: Beautiful text and HTML displays for terminal and Jupyter notebooks
- **Bypass Mode**: Enable/disable effect bypass where supported
- **Latency Information**: Query processing latency and tail time

## Requirements

- macOS (AudioUnits are a macOS-specific technology)
- Julia 1.6 or later

## Installation

```julia
# In development - will be registered in Julia package registry
using Pkg
Pkg.add(url="https://github.com/yourusername/AudioUnits.jl")
```

## Quick Start

```julia
using AudioUnits

# List all available AudioUnits
all_units = find_audiounits()
println("Found ", length(all_units), " AudioUnits")

# Find only effect processors
effects = find_audiounits(kAudioUnitType_Effect)

# Find music devices (instruments)
instruments = find_audiounits(kAudioUnitType_MusicDevice)

# Load a specific AudioUnit by name
au = load_audiounit("AULowpass")

# Initialize it for use
initialize_audiounit(au)

# Get all parameters
params = get_parameters(au)

# Get detailed information
info = get_info(au)
println("AudioUnit: ", info.name, " v", join(info.version, "."))
println("Parameters: ", info.parameter_count)

# Set a parameter value
if !isempty(params)
    param = params[1]
    set_parameter_value(au, param.id, 0.5)
    current = get_parameter_value(au, param.id)
    println("Parameter value: ", current)
end

# Generate comprehensive documentation
doc = get_documentation(au)
println(doc)

# Clean up
uninitialize_audiounit(au)
dispose_audiounit(au)
```

## Display in Terminal and Jupyter Notebooks

AudioUnits.jl provides rich display functionality for both terminal (REPL) and Jupyter notebooks:

### Terminal Display

```julia
using AudioUnits

au = load_audiounit("AULowpass")
initialize_audiounit(au)

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
au = load_audiounit("AULowpass")
initialize_audiounit(au)
au  # Displays with rich HTML formatting
```

Features:
- Color-coded status badges
- Two-column grid layout
- Scrollable parameter tables
- Professional styling with inline CSS

### Display Parameters

```julia
params = get_parameters(au)
display(params[1])  # Shows parameter details
```

See `examples/display_demo.jl` and `examples/notebook_example.md` for more details.

## API Reference

### AudioUnit Discovery

```julia
find_audiounits([type]) -> Vector{NamedTuple}
```
Find all AudioUnits, optionally filtered by type.

```julia
list_all_audiounits(; type=nothing) -> String
```
Get a formatted list of all available AudioUnits.

### AudioUnit Loading and Management

```julia
load_audiounit(name::String) -> AudioUnit
load_audiounit(type::AudioUnitType, subtype::UInt32) -> AudioUnit
```
Load an AudioUnit by name or type/subtype identifier.

```julia
initialize_audiounit(au::AudioUnit) -> Bool
uninitialize_audiounit(au::AudioUnit) -> Bool
dispose_audiounit(au::AudioUnit)
```
Initialize, uninitialize, and dispose of AudioUnit instances.

### Parameter Management

```julia
get_parameters(au::AudioUnit; scope=kAudioUnitScope_Global) -> Vector{AudioUnitParameter}
```
Get all parameters for an AudioUnit.

```julia
get_parameter_info(au::AudioUnit, param_id::UInt32, scope=kAudioUnitScope_Global) -> AudioUnitParameterInfo
```
Get detailed information about a specific parameter.

```julia
get_parameter_value(au::AudioUnit, param_id::UInt32; scope, element) -> Float32
set_parameter_value(au::AudioUnit, param_id::UInt32, value::Real; scope, element) -> Bool
```
Get or set parameter values.

### Capability Detection

```julia
supports_effects(au::AudioUnit) -> Bool
supports_midi(au::AudioUnit) -> Bool
can_bypass(au::AudioUnit) -> Bool
```
Check AudioUnit capabilities.

```julia
get_channel_capabilities(au::AudioUnit) -> Vector{NamedTuple}
get_stream_format(au::AudioUnit; scope, element) -> NamedTuple
get_latency(au::AudioUnit) -> Float64
get_tail_time(au::AudioUnit) -> Float64
```
Query processing characteristics.

```julia
set_bypass(au::AudioUnit, bypass::Bool) -> Bool
```
Enable or disable effect bypass.

### MIDI Functions

```julia
send_midi_event(au::AudioUnit, status::UInt8, data1::UInt8, data2::UInt8) -> Bool
```
Send a raw MIDI event to a music device AudioUnit.

```julia
note_on(au::AudioUnit, note::Integer, velocity::Integer=100; channel::Integer=0) -> Bool
note_off(au::AudioUnit, note::Integer; channel::Integer=0) -> Bool
```
Send MIDI Note On/Off messages.

```julia
control_change(au::AudioUnit, controller::Integer, value::Integer; channel::Integer=0) -> Bool
program_change(au::AudioUnit, program::Integer; channel::Integer=0) -> Bool
pitch_bend(au::AudioUnit, value::Integer; channel::Integer=0) -> Bool
```
Send MIDI Control Change, Program Change, and Pitch Bend messages.

```julia
all_notes_off(au::AudioUnit; channel::Integer=0) -> Bool
```
Turn off all notes on a MIDI channel.

### Documentation

```julia
get_documentation(au::AudioUnit) -> String
get_info(au::AudioUnit) -> NamedTuple
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

## Notes

- AudioUnits must be initialized before most operations (except parameter queries)
- Always dispose of AudioUnits when done to free system resources
- Some parameters may be read-only or have special constraints
- Not all AudioUnits support all features (bypass, MIDI, etc.)
- **MIDI Note**: While MIDI messages can be sent to music devices, actual audio output requires setting up an AUGraph (Audio Unit Graph) to connect the music device to an output unit. This functionality may be added in future versions.

## License

This package is provided as-is. Check the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.
