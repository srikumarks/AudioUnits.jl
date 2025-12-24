module AudioUnits

export AudioUnit, AudioUnitParameter, AudioUnitType, AudioUnitParameterInfo
export AudioUnitInfo, ChannelConfiguration, StreamFormat, AudioUnitSummary, AudioTimeStampInfo
export AudioGraph, AudioProcessor
export issupported
export findaudiounits, load, parameters, parameterinfo
export supportseffects, supportsmidi, documentation, info
export parametervalue, setparametervalue!
export streamformat, channelcapabilities
export initialize, uninitialize, dispose
export sendmidi, noteon, noteoff, controlchange, programchange
export pitchbend, allnotesoff
export canbypass, setbypass!, latency, tailtime, listall
export blocksize, setblocksize!, currenttimestamp
export addnode!, addoutputnode!, connect!, initializegraph!, uninitializegraph!
export disposegraph!, startgraph!, stopgraph!, processbuffer
# Note: process and process! are now primarily defined in processor.jl for AudioProcessor
# The old process! from graph.jl is still exported for compatibility
export process, process!

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
include("processor.jl")
include("graph.jl")

end # module
