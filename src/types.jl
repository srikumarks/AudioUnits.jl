# AudioUnit Types and Structures

"""
    AudioUnitType

Enumeration of AudioUnit types.
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

Represents a loaded AudioUnit instance.
"""
mutable struct AudioUnit
    component::Ptr{Cvoid}
    instance::Ptr{Cvoid}
    name::String
    manufacturer::String
    version::UInt32
    au_type::AudioUnitType
    subtype::UInt32
    initialized::Bool

    function AudioUnit(component::Ptr{Cvoid}, instance::Ptr{Cvoid},
                      name::String, manufacturer::String, version::UInt32,
                      au_type::AudioUnitType, subtype::UInt32)
        new(component, instance, name, manufacturer, version, au_type, subtype, false)
    end
end

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
const kAudioUnitScope_Global = 0
const kAudioUnitScope_Input = 1
const kAudioUnitScope_Output = 2
const kAudioUnitScope_Group = 3
const kAudioUnitScope_Part = 4
const kAudioUnitScope_Note = 5
const kAudioUnitScope_Layer = 6
const kAudioUnitScope_LayerItem = 7

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
