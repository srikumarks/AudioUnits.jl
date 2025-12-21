module AudioUnits

export AudioUnit, AudioUnitParameter, AudioUnitType
export find_audiounits, load_audiounit, get_parameters, get_parameter_info
export supports_effects, supports_midi, get_documentation
export get_parameter_value, set_parameter_value
export initialize_audiounit, uninitialize_audiounit, dispose_audiounit

using Libdl

# Load AudioToolbox framework
const AudioToolbox = "/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox"

include("types.jl")
include("core.jl")
include("parameters.jl")
include("capabilities.jl")
include("documentation.jl")

end # module
