# Public API with Julia naming conventions
# This file defines the public API function names that follow Julia conventions
# and delegates to the internal implementation functions.

# Core functions
const findaudiounits = find_audiounits
const load = load_audiounit
const initialize = initialize_audiounit
const uninitialize = uninitialize_audiounit
const dispose = dispose_audiounit

# Parameter functions
const parameters = get_parameters
const parameterinfo = get_parameter_info
const parametervalue = get_parameter_value
const setparametervalue! = set_parameter_value

# Capability functions
const supportseffects = supports_effects
const supportsmidi = supports_midi
const streamformat = get_stream_format
const channelcapabilities = get_channel_capabilities
const canbypass = can_bypass
const setbypass! = set_bypass
const latency = get_latency
const tailtime = get_tail_time

# Documentation functions
const documentation = get_documentation
const info = get_info
const listall = list_all_audiounits

# MIDI functions
const sendmidi = send_midi_event
const noteon = note_on
const noteoff = note_off
const controlchange = control_change
const programchange = program_change
const pitchbend = pitch_bend
const allnotesoff = all_notes_off
