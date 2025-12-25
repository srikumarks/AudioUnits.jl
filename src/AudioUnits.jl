module AudioUnits

export AudioUnit, AudioUnitParameter, AudioUnitType, AudioUnitParameterInfo
export AudioUnitInfo, ChannelConfiguration, StreamFormat, AudioUnitSummary, AudioTimeStampInfo
export AudioEngine, AudioProcessor
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
export process, process!

using Libdl

# Include ObjectiveC bridge FIRST - all other modules depend on it
include("objc_bridge.jl")

# Load remaining modules
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
