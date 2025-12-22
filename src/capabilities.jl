# AudioUnit capability detection

"""
    supportseffects(au::AudioUnit) -> Bool

Check if an AudioUnit supports audio effects processing.

Returns `true` if the AudioUnit is an effect processor, `false` otherwise.

# Examples
```julia
au = load("AULowpass")
if supportseffects(au)
    println("This is an effects processor")
end
```
"""
function supportseffects(au::AudioUnit)
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
    supportsmidi(au::AudioUnit) -> Bool

Check if an AudioUnit accepts MIDI input (i.e., is a music device/instrument).

Returns `true` if the AudioUnit can receive MIDI messages, `false` otherwise.

# Examples
```julia
au = load("DLSMusicDevice")
if supportsmidi(au)
    println("This AudioUnit accepts MIDI input")
end
```
"""
function supportsmidi(au::AudioUnit)
    # Music devices and music effects typically support MIDI
    return au.au_type in [
        kAudioUnitType_MusicDevice,
        kAudioUnitType_MusicEffect
    ]
end

"""
    streamformat(au::AudioUnit; scope::UInt32 = kAudioUnitScope_Output, element::UInt32 = 0) -> StreamFormat

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
format = streamformat(au)
println("Sample rate: ", format.sample_rate, " Hz")
println("Channels: ", format.channels_per_frame)
```
"""
function streamformat(au::AudioUnit;
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
    channelcapabilities(au::AudioUnit) -> Vector{ChannelConfiguration}

Get the supported channel configurations for an AudioUnit.

Returns a vector of `ChannelConfiguration` structs, each with:
- `input_channels`: Number of input channels
- `output_channels`: Number of output channels

# Examples
```julia
configs = channelcapabilities(au)
for config in configs
    println("In: ", config.input_channels, " Out: ", config.output_channels)
end
```
"""
function channelcapabilities(au::AudioUnit)
    size = Ref{UInt32}(0)
    writable = Ref{UInt32}(0)

    # Get size of the supported channel configuration list
    status = ccall((:AudioUnitGetPropertyInfo, AudioToolbox), Int32,
                  (Ptr{Cvoid}, UInt32, UInt32, UInt32, Ptr{UInt32}, Ptr{UInt32}),
                  au.instance, kAudioUnitProperty_SupportedNumChannels,
                  kAudioUnitScope_Global, 0, size, writable)

    if status != noErr || size[] == 0
        # If property not supported, return default based on type
        if supportsmidi(au)
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
    latency(au::AudioUnit) -> Float64

Get the processing latency of an AudioUnit in seconds.

# Examples
```julia
lat = latency(au)
println("Latency: ", lat * 1000, " ms")
```
"""
function latency(au::AudioUnit)
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
    tailtime(au::AudioUnit) -> Float64

Get the tail time of an AudioUnit in seconds.

The tail time is how long the effect continues to output audio after the input stops
(e.g., reverb decay time).

# Examples
```julia
tail = tailtime(au)
println("Tail time: ", tail, " seconds")
```
"""
function tailtime(au::AudioUnit)
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
    canbypass(au::AudioUnit) -> Bool

Check if an AudioUnit supports bypass mode.

# Examples
```julia
if canbypass(au)
    setbypass!(au, true)  # Enable bypass
end
```
"""
function canbypass(au::AudioUnit)
    size = Ref{UInt32}(0)
    writable = Ref{UInt32}(0)

    status = ccall((:AudioUnitGetPropertyInfo, AudioToolbox), Int32,
                  (Ptr{Cvoid}, UInt32, UInt32, UInt32, Ptr{UInt32}, Ptr{UInt32}),
                  au.instance, kAudioUnitProperty_BypassEffect,
                  kAudioUnitScope_Global, 0, size, writable)

    return status == noErr && size[] > 0
end

"""
    setbypass!(au::AudioUnit, bypass::Bool) -> Bool

Enable or disable bypass mode for an AudioUnit.

Returns `true` on success, `false` otherwise.

# Examples
```julia
setbypass!(au, true)   # Bypass the effect
setbypass!(au, false)  # Re-enable the effect
```
"""
function setbypass!(au::AudioUnit, bypass::Bool)
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

"""
    blocksize(au::AudioUnit) -> UInt32

Get the maximum number of audio frames (block size) the AudioUnit processes per render slice.

Returns the block size in frames. This is the size of audio buffers passed to the AudioUnit
during rendering.

# Examples
```julia
size = blocksize(au)
println("Block size: ", size, " frames")
```
"""
function blocksize(au::AudioUnit)
    size = Ref{UInt32}(4)
    frames = Ref{UInt32}(0)

    status = ccall((:AudioUnitGetProperty, AudioToolbox), Int32,
                  (Ptr{Cvoid}, UInt32, UInt32, UInt32, Ptr{UInt32}, Ptr{UInt32}),
                  au.instance, kAudioUnitProperty_MaximumFramesPerSlice,
                  kAudioUnitScope_Global, 0, frames, size)

    return status == noErr ? frames[] : UInt32(0)
end

"""
    setblocksize!(au::AudioUnit, frames::Integer) -> Bool

Set the maximum number of audio frames (block size) the AudioUnit processes per render slice.

Returns `true` on success, `false` otherwise.

# Arguments
- `au::AudioUnit`: The AudioUnit instance
- `frames::Integer`: The block size in frames (typically 64, 128, 256, 512, or 1024)

# Examples
```julia
# Set block size to 256 frames
setblocksize!(au, 256)
```
"""
function setblocksize!(au::AudioUnit, frames::Integer)
    @assert frames > 0 "Block size must be greater than 0, got $frames"

    frames_val = Ref{UInt32}(UInt32(frames))

    status = ccall((:AudioUnitSetProperty, AudioToolbox), Int32,
                  (Ptr{Cvoid}, UInt32, UInt32, UInt32, Ptr{UInt32}, UInt32),
                  au.instance, kAudioUnitProperty_MaximumFramesPerSlice,
                  kAudioUnitScope_Global, 0, frames_val, 4)

    if status != noErr
        @error "Failed to set block size: OSStatus $status"
        return false
    end

    return true
end

"""
    currenttimestamp(au::AudioUnit) -> AudioTimeStampInfo

Get the current audio timestamp for the AudioUnit.

Returns an `AudioTimeStampInfo` struct containing:
- `sample_time`: Current sample position
- `sample_rate`: Sample rate in Hz
- `flags`: Timestamp flags indicating which fields are valid

# Examples
```julia
ts = currenttimestamp(au)
println("Current sample time: ", ts.sample_time)
println("Sample rate: ", ts.sample_rate, " Hz")
```
"""
function currenttimestamp(au::AudioUnit)
    # AudioTimeStamp structure (56 bytes on 64-bit systems)
    # We'll query it via GetProperty
    size = Ref{UInt32}(56)
    timestamp_buffer = zeros(UInt8, 56)

    status = ccall((:AudioUnitGetProperty, AudioToolbox), Int32,
                  (Ptr{Cvoid}, UInt32, UInt32, UInt32, Ptr{UInt8}, Ptr{UInt32}),
                  au.instance, 229,  # kAudioUnitProperty_CurrentPlayTime = 229
                  kAudioUnitScope_Global, 0, timestamp_buffer, size)

    if status != noErr
        # Return default if property not available
        return AudioTimeStampInfo(0.0, 0.0, 0)
    end

    # Parse AudioTimeStamp structure
    # mSampleTime (Float64) at offset 0
    # mHostTime (UInt64) at offset 8
    # mRateScalar (Float64) at offset 16
    # mWordClockTime (SMPTETime) at offset 24
    # mSMPTEResolution (UInt32) at offset 40
    # mFlags (UInt32) at offset 44
    # mReserved (UInt32) at offset 48
    # mReservedA (UInt32) at offset 52

    ptr = pointer(timestamp_buffer)
    sample_time = unsafe_load(Ptr{Float64}(ptr))
    flags = unsafe_load(Ptr{UInt32}(ptr + 44))

    # Try to get sample rate from the AudioUnit's stream format
    sample_rate = 44100.0  # Default
    fmt = try
        streamformat(au)
    catch
        nothing
    end

    if !isnothing(fmt)
        sample_rate = fmt.sample_rate
    end

    return AudioTimeStampInfo(sample_time, sample_rate, flags)
end
