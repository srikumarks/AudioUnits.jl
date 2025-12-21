module AudioUnits

export AudioUnit, AudioUnitParameter, AudioUnitType, AudioUnitParameterInfo
export AudioUnitInfo, ChannelConfiguration, StreamFormat, AudioUnitSummary
export find_audiounits, load_audiounit, get_parameters, get_parameter_info
export supports_effects, supports_midi, get_documentation, get_info
export get_parameter_value, set_parameter_value
export get_stream_format, get_channel_capabilities
export initialize_audiounit, uninitialize_audiounit, dispose_audiounit
export send_midi_event, note_on, note_off, control_change, program_change
export pitch_bend, all_notes_off

using Libdl

# Load AudioToolbox framework
const AudioToolbox = "/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox"

include("types.jl")
include("core.jl")
include("parameters.jl")
include("capabilities.jl")
include("documentation.jl")
include("display.jl")
include("midi.jl")

end # module
