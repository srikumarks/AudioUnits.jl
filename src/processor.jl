# AudioProcessor - Safe, block-based offline audio processing for AUv3
#
# This module provides AudioProcessor, a stateful object that manages
# block-by-block audio processing using AVAudioEngine's manual rendering mode.
# This is the proper AUv3 way to do offline audio processing.

# ============================================================================
# Additional ObjC Wrappers
# ============================================================================

@objcwrapper AVAudioUnitEffect <: AVAudioNode
# Note: Use AVAudioPlayerNode from objc_bridge.jl

"""
    AudioProcessor

A stateful processor that safely manages offline audio processing for an AUv3 AudioUnit.

Uses AVAudioEngine with manual rendering mode for thread-safe offline processing.
This approach avoids callback threading issues and provides reliable block-by-block
audio rendering.

# Fields
- `au::AudioUnit`: The AUv3 AudioUnit being processed (must be initialized)
- `engine`: The AVAudioEngine instance
- `effect_node`: The effect node in the engine
- `player_node`: The player node providing input audio
- `input_buffer`: Pre-allocated input buffer
- `output_buffer`: Pre-allocated output buffer
- `max_channels::Int`: Maximum number of channels supported
- `max_frames::Int`: Maximum number of frames per process call
- `sample_rate::Float64`: Sample rate in Hz
- `initialized::Bool`: Whether the processor has been set up

# Example
```julia
using AudioUnits

# Create processor
au = load("AULowpass")
initialize(au)
processor = AudioProcessor(au, max_channels=2, max_frames=128)

# Process audio incrementally (128-sample blocks)
input_data = randn(Float32, 2, 128)
output_data = processor(input_data)

# Clean up
dispose(processor)
uninitialize(au)
dispose(au)
```
"""
mutable struct AudioProcessor
    au::AudioUnit

    # AVAudioEngine components
    engine::Any  # id{AVAudioEngine}
    effect_node::Any  # id{AVAudioUnitEffect}
    player_node::Any  # id{AVAudioPlayerNode}
    mixer_node::Any  # id{AVAudioNode}
    format::Any  # id{AVAudioFormat}

    # Pre-allocated buffers
    input_buffer::Any  # id{AVAudioPCMBuffer}
    output_buffer::Any  # id{AVAudioPCMBuffer}

    # Julia-side data buffers
    input_data::Matrix{Float32}
    output_data::Matrix{Float32}

    # Metadata
    max_channels::Int
    max_frames::Int
    sample_rate::Float64

    # State
    initialized::Bool
end

# ============================================================================
# Constructor
# ============================================================================

"""
    AudioProcessor(au::AudioUnit; max_channels=2, max_frames=128, sample_rate=44100.0)

Create a new AudioProcessor for block-based processing with an AUv3 AudioUnit.

# Arguments
- `au::AudioUnit`: The AUv3 AudioUnit to process with (must be initialized)
- `max_channels::Int`: Maximum number of audio channels (default: 2)
- `max_frames::Int`: Maximum number of frames per block (default: 128 for real-time blocks)
- `sample_rate::Float64`: Sample rate in Hz (default: 44100.0)

# Returns
A new AudioProcessor ready for block-based processing

# Throws
- `ErrorException` if the AudioUnit is not initialized or if engine setup fails
"""
function AudioProcessor(au::AudioUnit;
                       max_channels::Int=2,
                       max_frames::Int=128,
                       sample_rate::Float64=44100.0)
    if !au.initialized
        error("AudioUnit must be initialized before creating AudioProcessor")
    end

    @assert max_channels > 0 "max_channels must be positive"
    @assert max_frames > 0 "max_frames must be positive"
    @assert sample_rate > 0 "sample_rate must be positive"

    # Create AVAudioEngine
    engine_alloc = @objc [AVAudioEngine alloc]::id{AVAudioEngine}
    engine = @objc [engine_alloc::id{AVAudioEngine} init]::id{AVAudioEngine}
    mixer_node = @objc [engine::id{AVAudioEngine} mainMixerNode]::id{AVAudioNode}

    # Get component description from AU
    desc = @objc [au.instance::id{AUAudioUnit} componentDescription]::AudioComponentDescription

    # Create AVAudioUnitEffect from the component
    effect_alloc = @objc [AVAudioUnitEffect alloc]::id{AVAudioUnitEffect}
    effect_node = ccall(:objc_msgSend, id{AVAudioUnitEffect},
        (id{AVAudioUnitEffect}, Ptr{Cvoid}, Ptr{AudioComponentDescription}),
        effect_alloc, sel"initWithAudioComponentDescription:", Ref(desc))

    if effect_node == nil
        error("Failed to create AVAudioUnitEffect from AudioUnit")
    end

    # Attach effect to engine
    @objc [engine::id{AVAudioEngine} attachNode:effect_node::id{AVAudioNode}]::Nothing

    # Create player node
    player_alloc = @objc [AVAudioPlayerNode alloc]::id{AVAudioPlayerNode}
    player_node = @objc [player_alloc::id{AVAudioPlayerNode} init]::id{AVAudioPlayerNode}
    @objc [engine::id{AVAudioEngine} attachNode:player_node::id{AVAudioNode}]::Nothing

    # Get output format from mixer (uses system default)
    output_format = @objc [mixer_node::id{AVAudioNode} outputFormatForBus:0::UInt]::id{AVAudioFormat}

    # Connect: player -> effect -> mixer
    connect_sel = sel"connect:to:format:"
    ccall(:objc_msgSend, Nothing,
        (id{AVAudioEngine}, Ptr{Cvoid}, id{AVAudioNode}, id{AVAudioNode}, id{AVAudioFormat}),
        engine, connect_sel, player_node, effect_node, output_format)
    ccall(:objc_msgSend, Nothing,
        (id{AVAudioEngine}, Ptr{Cvoid}, id{AVAudioNode}, id{AVAudioNode}, id{AVAudioFormat}),
        engine, connect_sel, effect_node, mixer_node, output_format)

    # Enable manual rendering mode
    error_ptr = Ptr{Cvoid}[C_NULL]
    manual_sel = sel"enableManualRenderingMode:format:maximumFrameCount:error:"
    success = ccall(:objc_msgSend, Bool,
        (id{AVAudioEngine}, Ptr{Cvoid}, UInt32, id{AVAudioFormat}, UInt32, Ptr{Ptr{Cvoid}}),
        engine, manual_sel, UInt32(0), output_format, UInt32(max_frames * 4), pointer(error_ptr))

    if !success
        error("Failed to enable manual rendering mode")
    end

    # Get the actual rendering format
    rendering_format = ccall(:objc_msgSend, id{AVAudioFormat},
        (id{AVAudioEngine}, Ptr{Cvoid}), engine, sel"manualRenderingFormat")

    actual_sample_rate = @objc [rendering_format::id{AVAudioFormat} sampleRate]::Float64
    actual_channels = @objc [rendering_format::id{AVAudioFormat} channelCount]::UInt32

    # Prepare and start engine
    @objc [engine::id{AVAudioEngine} prepare]::Nothing
    start_sel = sel"startAndReturnError:"
    started = ccall(:objc_msgSend, Bool,
        (id{AVAudioEngine}, Ptr{Cvoid}, Ptr{Ptr{Cvoid}}),
        engine, start_sel, pointer(error_ptr))

    if !started
        error("Failed to start AVAudioEngine")
    end

    # Create pre-allocated buffers
    init_sel = sel"initWithPCMFormat:frameCapacity:"

    # Input buffer
    input_buffer_alloc = @objc [AVAudioPCMBuffer alloc]::id{AVAudioPCMBuffer}
    input_buffer = ccall(:objc_msgSend, id{AVAudioPCMBuffer},
        (id{AVAudioPCMBuffer}, Ptr{Cvoid}, id{AVAudioFormat}, UInt32),
        input_buffer_alloc, init_sel, rendering_format, UInt32(max_frames))

    # Output buffer
    output_buffer_alloc = @objc [AVAudioPCMBuffer alloc]::id{AVAudioPCMBuffer}
    output_buffer = ccall(:objc_msgSend, id{AVAudioPCMBuffer},
        (id{AVAudioPCMBuffer}, Ptr{Cvoid}, id{AVAudioFormat}, UInt32),
        output_buffer_alloc, init_sel, rendering_format, UInt32(max_frames))

    # Julia-side data buffers
    input_data = zeros(Float32, Int(actual_channels), max_frames)
    output_data = zeros(Float32, Int(actual_channels), max_frames)

    processor = AudioProcessor(
        au,
        engine, effect_node, player_node, mixer_node, rendering_format,
        input_buffer, output_buffer,
        input_data, output_data,
        Int(actual_channels), max_frames, actual_sample_rate,
        true
    )

    return processor
end

# ============================================================================
# Public API: process!()
# ============================================================================

"""
    process!(processor::AudioProcessor, input_data::Matrix{Float32}) -> Matrix{Float32}

Process a block of audio through the AudioProcessor using AVAudioEngine.

This is the core function for block-based processing. Schedules input audio on the
player node, renders through the effect, and returns the processed output.

# Arguments
- `processor::AudioProcessor`: The processor to use
- `input_data::Matrix{Float32}`: Input audio (channels × frames)

# Returns
- `Matrix{Float32}`: Processed audio (channels × frames)

# Throws
- `AssertionError` if input dimensions exceed processor's maximums
- `ErrorException` if rendering fails
"""
function process!(processor::AudioProcessor, input_data::Matrix{Float32})
    nchannels, nframes = size(input_data)

    # Validate dimensions
    @assert nchannels <= processor.max_channels "Input has $nchannels channels, processor supports max $(processor.max_channels)"
    @assert nframes <= processor.max_frames "Input has $nframes frames, processor supports max $(processor.max_frames)"

    # Copy input to persistent buffer
    processor.input_data[1:nchannels, 1:nframes] .= input_data

    # Set frame length on input buffer
    ccall(:objc_msgSend, Nothing,
        (id{AVAudioPCMBuffer}, Ptr{Cvoid}, UInt32),
        processor.input_buffer, sel"setFrameLength:", UInt32(nframes))

    # Copy input data to AVAudioPCMBuffer
    channel_data_ptr = @objc [processor.input_buffer::id{AVAudioPCMBuffer} floatChannelData]::Ptr{Ptr{Float32}}
    for ch in 1:nchannels
        ch_ptr = unsafe_load(channel_data_ptr, ch)
        for i in 1:nframes
            unsafe_store!(ch_ptr, processor.input_data[ch, i], i)
        end
    end

    # Schedule buffer on player (with loop to ensure data is available)
    schedule_sel = sel"scheduleBuffer:atTime:options:completionHandler:"
    ccall(:objc_msgSend, Nothing,
        (id{AVAudioPlayerNode}, Ptr{Cvoid}, id{AVAudioPCMBuffer}, Ptr{Cvoid}, UInt32, Ptr{Cvoid}),
        processor.player_node, schedule_sel, processor.input_buffer, C_NULL, UInt32(1), C_NULL)

    # Make sure player is playing
    is_playing = @objc [processor.player_node::id{AVAudioPlayerNode} isPlaying]::Bool
    if !is_playing
        @objc [processor.player_node::id{AVAudioPlayerNode} play]::Nothing
    end

    # Render offline
    error_ptr = Ptr{Cvoid}[C_NULL]
    render_sel = sel"renderOffline:toBuffer:error:"
    result = ccall(:objc_msgSend, UInt32,
        (id{AVAudioEngine}, Ptr{Cvoid}, UInt32, id{AVAudioPCMBuffer}, Ptr{Ptr{Cvoid}}),
        processor.engine, render_sel, UInt32(nframes), processor.output_buffer, pointer(error_ptr))

    # Check result (0 = success in AVAudioEngineManualRenderingStatus)
    if result != 0
        if error_ptr[1] != C_NULL
            err = reinterpret(id{NSError}, error_ptr[1])
            err_desc = get_nserror_description(err)
            error("Render failed: $err_desc")
        else
            error("Render failed with status $result")
        end
    end

    # Copy output from AVAudioPCMBuffer to Julia array
    out_len = @objc [processor.output_buffer::id{AVAudioPCMBuffer} frameLength]::UInt32
    out_data_ptr = @objc [processor.output_buffer::id{AVAudioPCMBuffer} floatChannelData]::Ptr{Ptr{Float32}}

    actual_frames = min(Int(out_len), nframes)
    for ch in 1:nchannels
        ch_ptr = unsafe_load(out_data_ptr, ch)
        for i in 1:actual_frames
            processor.output_data[ch, i] = unsafe_load(ch_ptr, i)
        end
    end

    # Return copy of output (not view, for safety)
    return copy(processor.output_data[1:nchannels, 1:actual_frames])
end

# ============================================================================
# Callable interface
# ============================================================================

"""
    (processor::AudioProcessor)(input_data::Matrix{Float32}) -> Matrix{Float32}

Functor interface for processing audio. Equivalent to calling process!().
"""
function (processor::AudioProcessor)(input_data::Matrix{Float32})
    return process!(processor, input_data)
end

# ============================================================================
# Utility functions
# ============================================================================

"""
    reset!(processor::AudioProcessor)

Reset the processor state. Stops and restarts the player node.
"""
function reset!(processor::AudioProcessor)
    if processor.initialized
        @objc [processor.player_node::id{AVAudioPlayerNode} stop]::Nothing
        @objc [processor.player_node::id{AVAudioPlayerNode} play]::Nothing
    end
end

# ============================================================================
# Cleanup
# ============================================================================

"""
    dispose(processor::AudioProcessor)

Clean up the AudioProcessor and release its resources.

# Arguments
- `processor::AudioProcessor`: The processor to clean up
"""
function dispose(processor::AudioProcessor)
    if processor.initialized
        # Stop player
        try
            @objc [processor.player_node::id{AVAudioPlayerNode} stop]::Nothing
        catch
        end

        # Stop engine
        try
            @objc [processor.engine::id{AVAudioEngine} stop]::Nothing
        catch
        end

        processor.initialized = false
    end

    # Clear references (let GC/ARC handle cleanup)
    processor.engine = nothing
    processor.effect_node = nothing
    processor.player_node = nothing
    processor.mixer_node = nothing
    processor.format = nothing
    processor.input_buffer = nothing
    processor.output_buffer = nothing
end
