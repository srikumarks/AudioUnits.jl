module AudioUnits

export AudioUnit, AudioUnitParameter, AudioUnitType, AudioUnitParameterInfo
export AudioUnitInfo, ChannelConfiguration, StreamFormat, AudioUnitSummary
export AudioGraph
export issupported
export findaudiounits, load, parameters, parameterinfo
export supportseffects, supportsmidi, documentation, info
export parametervalue, setparametervalue!
export streamformat, channelcapabilities
export initialize, uninitialize, dispose
export sendmidi, noteon, noteoff, controlchange, programchange
export pitchbend, allnotesoff
export canbypass, setbypass!, latency, tailtime, listall
export addnode!, addoutputnode!, connect!, initializegraph!, uninitializegraph!
export disposegraph!, startgraph!, stopgraph!, processbuffer, processbuffer!

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
include("graph.jl")

end # module
