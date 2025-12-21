# API Naming Convention Changes

This document lists the changes made to conform to Julia naming conventions.

## Principles
1. Remove underscores where they don't significantly improve readability
2. Use property-like names for getters (no "get" prefix)
3. Drop type name from functions where type dispatch makes it clear
4. Use `!` suffix for functions that mutate state

## Function Name Changes

### Core Functions
- `find_audiounits` → `findaudiounits`
- `load_audiounit` → `load`
- `initialize_audiounit` → `initialize`
- `uninitialize_audiounit` → `uninitialize`
- `dispose_audiounit` → `dispose`

### Parameter Functions
- `get_parameters` → `parameters`
- `get_parameter_info` → `parameterinfo`
- `get_parameter_value` → `parametervalue`
- `set_parameter_value` → `setparametervalue!`

### Capability Functions
- `supports_effects` → `supportseffects`
- `supports_midi` → `supportsmidi`
- `get_stream_format` → `streamformat`
- `get_channel_capabilities` → `channelcapabilities`
- `can_bypass` → `canbypass`
- `set_bypass` → `setbypass!`
- `get_latency` → `latency`
- `get_tail_time` → `tailtime`

### Documentation Functions
- `get_documentation` → `documentation`
- `get_info` → `info`
- `list_all_audiounits` → `listall`

### MIDI Functions
- `send_midi_event` → `sendmidi`
- `note_on` → `noteon`
- `note_off` → `noteoff`
- `control_change` → `controlchange`
- `program_change` → `programchange`
- `pitch_bend` → `pitchbend`
- `all_notes_off` → `allnotesoff`

## Type Names (unchanged)
Type names already follow UpperCamelCase convention:
- `AudioUnit`
- `AudioUnitParameter`
- `AudioUnitParameterInfo`
- `AudioUnitInfo`
- `ChannelConfiguration`
- `StreamFormat`
- `AudioUnitSummary`
- `AudioUnitType`

## Constants (unchanged)
Constants already follow convention with prefix:
- `kAudioUnitType_*`
- `kAudioUnitScope_*`
- `kAudioUnitProperty_*`
- `kAudioUnitParameterUnit_*`
