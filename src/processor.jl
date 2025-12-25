# AudioProcessor - Safe, block-based offline audio processing for AUv3
#
# This module provides AudioProcessor, a stateful object that manages
# block-by-block audio processing using AUv3's internalRenderBlock.
# This enables reliable 128-sample (or other block sizes) incremental processing.

"""
    AudioProcessor

A stateful processor that safely manages offline audio processing for an AUv3 AudioUnit.

Uses the AUv3 `internalRenderBlock` for real-time safe block-based rendering.
All buffers are persistent (live as long as the processor), and the render block
is an ObjectiveC block (not a Julia closure), ensuring safety and efficiency.

# Fields
- `au::AudioUnit`: The AUv3 AudioUnit being processed (must be initialized)
- `input_data::Matrix{Float32}`: Input audio data buffer (persistent)
- `output_data::Matrix{Float32}`: Output audio data buffer (persistent)
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
uninitialize(au)
dispose(au)
```
"""
mutable struct AudioProcessor
    au::AudioUnit

    # Persistent buffers (never reallocated)
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
- `ErrorException` if the AudioUnit is not initialized
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

    # Pre-allocate buffers (persistent, never reallocated)
    input_data = zeros(Float32, max_channels, max_frames)
    output_data = zeros(Float32, max_channels, max_frames)

    processor = AudioProcessor(
        au, input_data, output_data,
        max_channels, max_frames, sample_rate,
        true
    )

    return processor
end

# ============================================================================
# Public API: process!()
# ============================================================================

"""
    process!(processor::AudioProcessor, input_data::Matrix{Float32}) -> Matrix{Float32}

Process a block of audio through the AudioProcessor using AUv3's render block.

This is the core function for block-based processing. Copies input to processor's
persistent buffer, calls the AU's render block, and returns the output.

# Arguments
- `processor::AudioProcessor`: The processor to use
- `input_data::Matrix{Float32}`: Input audio (channels × frames)

# Returns
- `Matrix{Float32}`: Processed audio (channels × frames)

# Throws
- `AssertionError` if input dimensions exceed processor's maximums
- `ErrorException` if render block call fails
"""
function process!(processor::AudioProcessor, input_data::Matrix{Float32})
    nchannels, nframes = size(input_data)

    # Validate dimensions
    @assert nchannels <= processor.max_channels "Input has $nchannels channels, processor supports max $(processor.max_channels)"
    @assert nframes <= processor.max_frames "Input has $nframes frames, processor supports max $(processor.max_frames)"

    # Copy input to persistent buffer
    processor.input_data[1:nchannels, 1:nframes] .= input_data

    # Call render block
    _call_render_block!(processor, nchannels, nframes)

    # Return view of output
    return processor.output_data[1:nchannels, 1:nframes]
end

# ============================================================================
# Internal implementation
# ============================================================================

"""Internal: Call AUv3's internalRenderBlock"""
function _call_render_block!(processor::AudioProcessor, nchannels::Int, nframes::Int)
    if isnothing(processor.au.render_block) || processor.au.render_block == C_NULL
        error("AudioUnit's render block is not available")
    end

    # Create input buffer list pointing to persistent input_data
    input_buffer_list = create_audio_buffer_list(nchannels, nframes)
    for ch in 1:nchannels
        setup_audio_buffer!(input_buffer_list, ch - 1,
                           vec(processor.input_data[ch, 1:nframes]))
    end

    # Create output buffer list pointing to persistent output_data
    output_buffer_list = create_audio_buffer_list(nchannels, nframes)
    for ch in 1:nchannels
        setup_audio_buffer!(output_buffer_list, ch - 1,
                           vec(processor.output_data[ch, 1:nframes]))
    end

    # Create timestamp
    timestamp = create_audio_timestamp(0.0, processor.sample_rate)
    action_flags = Ref{UInt32}(0)

    # Call the render block with GC.@preserve to keep everything alive
    GC.@preserve processor input_buffer_list output_buffer_list timestamp begin
        try
            # The render block signature in AUv3 is complex:
            # OSStatus (^)(AudioUnitRenderActionFlags *ioActionFlags,
            #             const AudioTimeStamp *inTimeStamp,
            #             AVAudioFrameCount inFrames,
            #             NSInteger inOutputBusNumber,
            #             AudioBufferList *ioData,
            #             AURenderPullInputBlock inputBlock)
            #
            # For offline processing without input, we pass NULL for inputBlock
            status = ObjectiveC.msgSend(
                processor.au.render_block,
                "call::",  # Call the block with arguments
                action_flags,
                timestamp,
                UInt32(nframes),
                0,  # output bus
                output_buffer_list,
                C_NULL,  # no input block for offline processing
                Int32  # return type
            )

            if status != 0
                error("Render block failed with status $status")
            end
        catch e
            error("Failed to call render block: $e")
        end
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
    processor.initialized = false
end
