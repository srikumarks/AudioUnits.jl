# AudioUnit capability detection

"""
    supports_effects(au::AudioUnit) -> Bool

Check if an AudioUnit supports audio effects processing.

Returns `true` if the AudioUnit is an effect processor, `false` otherwise.

# Examples
```julia
au = load_audiounit("AULowpass")
if supports_effects(au)
    println("This is an effects processor")
end
```
"""
function supports_effects(au::AudioUnit)
    # Check if the AudioUnit type is an effect type
    return au.au_type in [
        kAudioUnitType_Effect,
        kAudioUnitType_MusicEffect,
        kAudioUnitType_FormatConverter,
        kAudioUnitType_Mixer,
        kAudioUnitType_Panner,
        kAudioUnitType_OfflineEffect
    ]
end

"""
    supports_midi(au::AudioUnit) -> Bool

Check if an AudioUnit accepts MIDI input (i.e., is a music device/instrument).

Returns `true` if the AudioUnit can receive MIDI messages, `false` otherwise.

# Examples
```julia
au = load_audiounit("DLSMusicDevice")
if supports_midi(au)
    println("This AudioUnit accepts MIDI input")
end
```
"""
function supports_midi(au::AudioUnit)
    # Music devices and music effects typically support MIDI
    return au.au_type in [
        kAudioUnitType_MusicDevice,
        kAudioUnitType_MusicEffect
    ]
end

"""
    get_stream_format(au::AudioUnit; scope::UInt32 = kAudioUnitScope_Output, element::UInt32 = 0) -> StreamFormat

Get the audio stream format for an AudioUnit.

Returns a `StreamFormat` struct with format information:
- `sample_rate`: Sample rate in Hz
- `format_id`: Audio format identifier
- `format_flags`: Format flags
- `bytes_per_packet`: Bytes per packet
- `frames_per_packet`: Frames per packet
- `bytes_per_frame`: Bytes per frame
- `channels_per_frame`: Number of audio channels
- `bits_per_channel`: Bits per channel

# Examples
```julia
format = get_stream_format(au)
println("Sample rate: ", format.sample_rate, " Hz")
println("Channels: ", format.channels_per_frame)
```
"""
function get_stream_format(au::AudioUnit;
                          scope::UInt32 = kAudioUnitScope_Output,
                          element::UInt32 = 0)
    # AudioStreamBasicDescription structure
    # typedef struct AudioStreamBasicDescription {
    #     Float64 mSampleRate;
    #     UInt32  mFormatID;
    #     UInt32  mFormatFlags;
    #     UInt32  mBytesPerPacket;
    #     UInt32  mFramesPerPacket;
    #     UInt32  mBytesPerFrame;
    #     UInt32  mChannelsPerFrame;
    #     UInt32  mBitsPerChannel;
    #     UInt32  mReserved;
    # } AudioStreamBasicDescription;

    size = Ref{UInt32}(40)  # Size of AudioStreamBasicDescription
    asbd = zeros(UInt8, 40)

    status = ccall((:AudioUnitGetProperty, AudioToolbox), Int32,
                  (Ptr{Cvoid}, UInt32, UInt32, UInt32, Ptr{UInt8}, Ptr{UInt32}),
                  au.instance, kAudioUnitProperty_StreamFormat,
                  scope, element, asbd, size)

    if status != noErr
        error("Failed to get stream format: OSStatus $status")
    end

    ptr = pointer(asbd)
    sample_rate = unsafe_load(Ptr{Float64}(ptr))
    format_id = unsafe_load(Ptr{UInt32}(ptr + 8))
    format_flags = unsafe_load(Ptr{UInt32}(ptr + 12))
    bytes_per_packet = unsafe_load(Ptr{UInt32}(ptr + 16))
    frames_per_packet = unsafe_load(Ptr{UInt32}(ptr + 20))
    bytes_per_frame = unsafe_load(Ptr{UInt32}(ptr + 24))
    channels_per_frame = unsafe_load(Ptr{UInt32}(ptr + 28))
    bits_per_channel = unsafe_load(Ptr{UInt32}(ptr + 32))

    return StreamFormat(
        sample_rate,
        format_id,
        format_flags,
        bytes_per_packet,
        frames_per_packet,
        bytes_per_frame,
        channels_per_frame,
        bits_per_channel
    )
end

"""
    get_channel_capabilities(au::AudioUnit) -> Vector{ChannelConfiguration}

Get the supported channel configurations for an AudioUnit.

Returns a vector of `ChannelConfiguration` structs, each with:
- `input_channels`: Number of input channels
- `output_channels`: Number of output channels

# Examples
```julia
configs = get_channel_capabilities(au)
for config in configs
    println("In: ", config.input_channels, " Out: ", config.output_channels)
end
```
"""
function get_channel_capabilities(au::AudioUnit)
    size = Ref{UInt32}(0)
    writable = Ref{UInt32}(0)

    # Get size of the supported channel configuration list
    status = ccall((:AudioUnitGetPropertyInfo, AudioToolbox), Int32,
                  (Ptr{Cvoid}, UInt32, UInt32, UInt32, Ptr{UInt32}, Ptr{UInt32}),
                  au.instance, kAudioUnitProperty_SupportedNumChannels,
                  kAudioUnitScope_Global, 0, size, writable)

    if status != noErr || size[] == 0
        # If property not supported, return default based on type
        if supports_midi(au)
            # Music devices typically output stereo
            return [ChannelConfiguration(0, 2)]
        else
            # Effects typically support various configurations
            return [ChannelConfiguration(2, 2)]
        end
    end

    # Each AUChannelInfo is 2 Int16s (4 bytes total)
    num_configs = size[] ÷ 4
    buffer = zeros(UInt8, size[])

    status = ccall((:AudioUnitGetProperty, AudioToolbox), Int32,
                  (Ptr{Cvoid}, UInt32, UInt32, UInt32, Ptr{UInt8}, Ptr{UInt32}),
                  au.instance, kAudioUnitProperty_SupportedNumChannels,
                  kAudioUnitScope_Global, 0, buffer, size)

    if status != noErr
        return ChannelConfiguration[]
    end

    configs = ChannelConfiguration[]
    ptr = pointer(buffer)

    for i in 0:(num_configs-1)
        in_channels = unsafe_load(Ptr{Int16}(ptr + i * 4))
        out_channels = unsafe_load(Ptr{Int16}(ptr + i * 4 + 2))
        push!(configs, ChannelConfiguration(in_channels, out_channels))
    end

    return configs
end

"""
    get_latency(au::AudioUnit) -> Float64

Get the processing latency of an AudioUnit in seconds.

# Examples
```julia
latency = get_latency(au)
println("Latency: ", latency * 1000, " ms")
```
"""
function get_latency(au::AudioUnit)
    if !au.initialized
        @warn "AudioUnit must be initialized to get accurate latency"
        return 0.0
    end

    size = Ref{UInt32}(8)
    latency = Ref{Float64}(0.0)

    status = ccall((:AudioUnitGetProperty, AudioToolbox), Int32,
                  (Ptr{Cvoid}, UInt32, UInt32, UInt32, Ptr{Float64}, Ptr{UInt32}),
                  au.instance, kAudioUnitProperty_Latency,
                  kAudioUnitScope_Global, 0, latency, size)

    return status == noErr ? latency[] : 0.0
end

"""
    get_tail_time(au::AudioUnit) -> Float64

Get the tail time of an AudioUnit in seconds.

The tail time is how long the effect continues to output audio after the input stops
(e.g., reverb decay time).

# Examples
```julia
tail = get_tail_time(au)
println("Tail time: ", tail, " seconds")
```
"""
function get_tail_time(au::AudioUnit)
    if !au.initialized
        return 0.0
    end

    size = Ref{UInt32}(8)
    tail_time = Ref{Float64}(0.0)

    status = ccall((:AudioUnitGetProperty, AudioToolbox), Int32,
                  (Ptr{Cvoid}, UInt32, UInt32, UInt32, Ptr{Float64}, Ptr{UInt32}),
                  au.instance, kAudioUnitProperty_TailTime,
                  kAudioUnitScope_Global, 0, tail_time, size)

    return status == noErr ? tail_time[] : 0.0
end

"""
    can_bypass(au::AudioUnit) -> Bool

Check if an AudioUnit supports bypass mode.

# Examples
```julia
if can_bypass(au)
    set_bypass(au, true)  # Enable bypass
end
```
"""
function can_bypass(au::AudioUnit)
    size = Ref{UInt32}(0)
    writable = Ref{UInt32}(0)

    status = ccall((:AudioUnitGetPropertyInfo, AudioToolbox), Int32,
                  (Ptr{Cvoid}, UInt32, UInt32, UInt32, Ptr{UInt32}, Ptr{UInt32}),
                  au.instance, kAudioUnitProperty_BypassEffect,
                  kAudioUnitScope_Global, 0, size, writable)

    return status == noErr && size[] > 0
end

"""
    set_bypass(au::AudioUnit, bypass::Bool) -> Bool

Enable or disable bypass mode for an AudioUnit.

Returns `true` on success, `false` otherwise.

# Examples
```julia
set_bypass(au, true)   # Bypass the effect
set_bypass(au, false)  # Re-enable the effect
```
"""
function set_bypass(au::AudioUnit, bypass::Bool)
    value = Ref{UInt32}(bypass ? 1 : 0)
    size = Ref{UInt32}(4)

    status = ccall((:AudioUnitSetProperty, AudioToolbox), Int32,
                  (Ptr{Cvoid}, UInt32, UInt32, UInt32, Ptr{UInt32}, UInt32),
                  au.instance, kAudioUnitProperty_BypassEffect,
                  kAudioUnitScope_Global, 0, value, 4)

    if status != noErr
        @error "Failed to set bypass: OSStatus $status"
        return false
    end

    return true
end
