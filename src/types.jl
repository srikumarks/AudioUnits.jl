# AudioUnit Types and Structures for AUv3

"""
    AudioUnitType

Enumeration of AudioUnit types (compatible with AUv2 and AUv3).
"""
@enum AudioUnitType begin
    kAudioUnitType_Output = 0x61756f75  # 'auou'
    kAudioUnitType_MusicDevice = 0x61756d75  # 'aumu'
    kAudioUnitType_MusicEffect = 0x61756d66  # 'aumf'
    kAudioUnitType_FormatConverter = 0x61756663  # 'aufc'
    kAudioUnitType_Effect = 0x61756678  # 'aufx'
    kAudioUnitType_Mixer = 0x61756d78  # 'aumx'
    kAudioUnitType_Panner = 0x6175706e  # 'aupn'
    kAudioUnitType_Generator = 0x6175676e  # 'augn'
    kAudioUnitType_OfflineEffect = 0x61756f6c  # 'auol'
end

"""
    AudioComponentDescription

Describes an AudioComponent for searching and identification.
"""
struct AudioComponentDescription
    componentType::UInt32
    componentSubType::UInt32
    componentManufacturer::UInt32
    componentFlags::UInt32
    componentFlagsMask::UInt32
end

"""
    AudioUnitParameterInfo

Information about an AudioUnit parameter.
"""
struct AudioUnitParameterInfo
    name::String
    unit_name::String
    min_value::Float32
    max_value::Float32
    default_value::Float32
    flags::UInt32
end

"""
    AudioUnitParameter

Represents a parameter of an AudioUnit.
"""
struct AudioUnitParameter
    id::UInt32
    scope::UInt32
    element::UInt32
    info::AudioUnitParameterInfo
end

"""
    AudioUnit

Represents a loaded AUv3 AudioUnit instance.

Fields:
- component: ObjectiveC.Object (AVAudioUnitComponent) - describes the available component
- instance: ObjectiveC.Object (AUAudioUnit) - the instantiated AudioUnit
- name: String - display name
- manufacturer: String - manufacturer name
- version: UInt32 - version number
- au_type: AudioUnitType - type of audio unit
- subtype: UInt32 - subtype identifier
- initialized: Bool - whether resources have been allocated
- parameter_tree: ObjectiveC.Object - cached parameter tree for performance
- render_block: ObjectiveC.Block - cached render block for processing
- allocated_resources: Bool - whether render resources are allocated
"""
mutable struct AudioUnit
    component::Any  # ObjectiveC.Object (AVAudioUnitComponent)
    instance::Any   # ObjectiveC.Object (AUAudioUnit)
    name::String
    manufacturer::String
    version::UInt32
    au_type::AudioUnitType
    subtype::UInt32
    initialized::Bool

    # AUv3-specific fields
    parameter_tree::Any  # Union{ObjectiveC.Object, Nothing}
    render_block::Any    # Union{ObjectiveC.Block, Nothing}
    allocated_resources::Bool

    function AudioUnit(
        component::Any,
        instance::Any,
        name::String,
        manufacturer::String,
        version::UInt32,
        au_type::AudioUnitType,
        subtype::UInt32
    )
        new(component, instance, name, manufacturer, version, au_type, subtype,
            false, nothing, nothing, false)
    end
end

"""
    AudioUnitInfo

Information about an available AudioUnit on the system.
"""
struct AudioUnitInfo
    name::String
    manufacturer::String
    type::AudioUnitType
    subtype::UInt32
    version::UInt32
end

"""
    ChannelConfiguration

Describes a supported input/output channel configuration for an AudioUnit.
"""
struct ChannelConfiguration
    input_channels::Int16
    output_channels::Int16
end

"""
    StreamFormat

Audio stream format information for an AudioUnit.
"""
struct StreamFormat
    sample_rate::Float64
    format_id::UInt32
    format_flags::UInt32
    bytes_per_packet::UInt32
    frames_per_packet::UInt32
    bytes_per_frame::UInt32
    channels_per_frame::UInt32
    bits_per_channel::UInt32
end

"""
    AudioUnitSummary

Summary information about an AudioUnit instance.
"""
struct AudioUnitSummary
    name::String
    manufacturer::String
    type::AudioUnitType
    subtype::UInt32
    version::Tuple{UInt16, UInt8, UInt8}
    supports_effects::Bool
    supports_midi::Bool
    can_bypass::Bool
    channel_configs::Vector{ChannelConfiguration}
    parameter_count::Int
    initialized::Bool
end

"""
    AudioTimeStampInfo

Timing information for audio rendering.
"""
struct AudioTimeStampInfo
    sample_time::Float64
    sample_rate::Float64
    flags::UInt32
end

"""
    AudioEngine

Represents an AVAudioEngine for connecting and processing AudioUnits.

AUv3 uses AVAudioEngine instead of AUGraph for building audio processing chains.
This provides realtime audio processing with automatic buffer management.

Fields:
- engine: ObjectiveC.Object (AVAudioEngine) - the underlying audio engine
- nodes: Dict{AudioUnit, ObjectiveC.Object} - mapping of AudioUnits to AVAudioNodes
- player_node: ObjectiveC.Object or nothing - optional input player node for offline processing
- output_node: ObjectiveC.Object (AVAudioOutputNode) - the engine's output node
- initialized: Bool - whether the engine has been initialized
- running: Bool - whether the engine is currently processing audio
"""
mutable struct AudioEngine
    engine::Any  # ObjectiveC.Object (AVAudioEngine)
    nodes::Dict{AudioUnit, Any}  # Maps AU to AVAudioNode
    player_node::Any  # Union{ObjectiveC.Object, Nothing}
    output_node::Any  # ObjectiveC.Object (AVAudioOutputNode)
    initialized::Bool
    running::Bool

    function AudioEngine(
        engine::Any,
        nodes::Dict{AudioUnit, Any},
        player_node::Any,
        output_node::Any,
        initialized::Bool,
        running::Bool
    )
        new(engine, nodes, player_node, output_node, initialized, running)
    end
end

# For backwards compatibility with code using AudioGraph name
const AudioGraph = AudioEngine

# AudioUnit Property IDs
const kAudioUnitProperty_ClassInfo = 0
const kAudioUnitProperty_MakeConnection = 1
const kAudioUnitProperty_SampleRate = 2
const kAudioUnitProperty_ParameterList = 3
const kAudioUnitProperty_ParameterInfo = 4
const kAudioUnitProperty_StreamFormat = 8
const kAudioUnitProperty_ElementCount = 11
const kAudioUnitProperty_Latency = 12
const kAudioUnitProperty_SupportedNumChannels = 13
const kAudioUnitProperty_MaximumFramesPerSlice = 14
const kAudioUnitProperty_AudioChannelLayout = 19
const kAudioUnitProperty_TailTime = 20
const kAudioUnitProperty_BypassEffect = 21
const kAudioUnitProperty_LastRenderError = 22
const kAudioUnitProperty_SetRenderCallback = 23
const kAudioUnitProperty_FactoryPresets = 24
const kAudioUnitProperty_ContextName = 25
const kAudioUnitProperty_HostCallbacks = 27
const kAudioUnitProperty_CocoaUI = 31

# AudioUnit Scopes
const kAudioUnitScope_Global = UInt32(0)
const kAudioUnitScope_Input = UInt32(1)
const kAudioUnitScope_Output = UInt32(2)
const kAudioUnitScope_Group = UInt32(3)
const kAudioUnitScope_Part = UInt32(4)
const kAudioUnitScope_Note = UInt32(5)
const kAudioUnitScope_Layer = UInt32(6)
const kAudioUnitScope_LayerItem = UInt32(7)

# Parameter Units
const kAudioUnitParameterUnit_Generic = 0
const kAudioUnitParameterUnit_Indexed = 1
const kAudioUnitParameterUnit_Boolean = 2
const kAudioUnitParameterUnit_Percent = 3
const kAudioUnitParameterUnit_Seconds = 4
const kAudioUnitParameterUnit_SampleFrames = 5
const kAudioUnitParameterUnit_Phase = 6
const kAudioUnitParameterUnit_Rate = 7
const kAudioUnitParameterUnit_Hertz = 8
const kAudioUnitParameterUnit_Cents = 9
const kAudioUnitParameterUnit_RelativeSemiTones = 10
const kAudioUnitParameterUnit_MIDINoteNumber = 11
const kAudioUnitParameterUnit_MIDIController = 12
const kAudioUnitParameterUnit_Decibels = 13
const kAudioUnitParameterUnit_LinearGain = 14
const kAudioUnitParameterUnit_Degrees = 15
const kAudioUnitParameterUnit_EqualPowerCrossfade = 16
const kAudioUnitParameterUnit_MixerFaderCurve1 = 17
const kAudioUnitParameterUnit_Pan = 18
const kAudioUnitParameterUnit_Meters = 19
const kAudioUnitParameterUnit_AbsoluteCents = 20
const kAudioUnitParameterUnit_Octaves = 21
const kAudioUnitParameterUnit_BPM = 22
const kAudioUnitParameterUnit_Beats = 23
const kAudioUnitParameterUnit_Milliseconds = 24
const kAudioUnitParameterUnit_Ratio = 25

# OSStatus codes
const noErr = 0
