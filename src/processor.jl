# AudioProcessor - Safe, persistent offline audio processing
#
# This module provides AudioProcessor, a stateful object that manages
# all buffers and callbacks for offline audio processing. This solves
# the memory safety issues with the deprecated processbuffer functions.

"""
    AudioProcessor

A stateful processor that safely manages offline audio processing for an AudioUnit.

All buffers are persistent (live as long as the processor), eliminating issues with
dangling pointers and garbage collection. The callback is module-level (not a closure),
ensuring compatibility with Julia's memory model.

# Fields
- `au::AudioUnit`: The AudioUnit being processed
- `input_buffer_list::Vector{UInt8}`: AudioBufferList for input (persistent)
- `output_buffer_list::Vector{UInt8}`: AudioBufferList for output (persistent)
- `input_data::Matrix{Float32}`: Input audio data buffer (persistent)
- `output_data::Matrix{Float32}`: Output audio data buffer (persistent)
- `callback_ptr::Base.CFunction`: Function pointer for render callback
- `callback_struct::Vector{UInt8}`: Callback registration structure
- `max_channels::Int`: Maximum number of channels supported
- `max_frames::Int`: Maximum number of frames per process call
- `sample_rate::Float64`: Sample rate in Hz
- `buffer_list_size::Int`: Size of AudioBufferList structure
- `initialized::Bool`: Whether the processor has been set up
- `callback_set::Bool`: Whether the callback is currently registered

# Example
```julia
using AudioUnits, SampledSignals

# Create processor
au = load("Apple: AULowpass")
initialize(au)
processor = AudioProcessor(au, max_channels=2, max_frames=4096)

# Process audio
input = SampleBuf(randn(Float32, 2, 1024), 44100.0)
output = process(processor, input)

# Clean up
dispose(processor)
uninitialize(au)
dispose(au)
```
"""
mutable struct AudioProcessor
    au::AudioUnit

    # Persistent buffers (never reallocated)
    input_buffer_list::Vector{UInt8}
    output_buffer_list::Vector{UInt8}
    input_data::Matrix{Float32}
    output_data::Matrix{Float32}

    # Callback function (defined at module level, not locally!)
    callback_ptr::Any  # Stores the CFunction object from @cfunction
    callback_struct::Vector{UInt8}

    # Metadata
    max_channels::Int
    max_frames::Int
    sample_rate::Float64
    buffer_list_size::Int

    # State
    initialized::Bool
    callback_set::Bool
end

# ============================================================================
# Module-level callback function (NOT a closure!)
# ============================================================================

"""
    audio_render_callback(inRefCon, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData)

Module-level render callback for AudioUnit. This function is not a closure,
so it can be safely used with @cfunction.

The `inRefCon` parameter points to an AudioProcessor object, which contains
all the persistent state needed for rendering.
"""
function audio_render_callback(inRefCon::Ptr{Cvoid},
                              ioActionFlags::Ptr{UInt32},
                              inTimeStamp::Ptr{UInt8},
                              inBusNumber::UInt32,
                              inNumberFrames::UInt32,
                              ioData::Ptr{UInt8})::Int32
    # Validate pointers
    if inRefCon == C_NULL || ioData == C_NULL
        return 0
    end

    try
        # Retrieve processor from inRefCon
        processor_ptr = unsafe_pointer_to_objref(inRefCon)::AudioProcessor

        # Copy from processor's persistent input_buffer_list
        input_list_ptr = pointer(processor_ptr.input_buffer_list)
        nbuffers = unsafe_load(Ptr{UInt32}(input_list_ptr))
        copysize = 4 + nbuffers * 16

        unsafe_copyto!(Ptr{UInt8}(ioData), input_list_ptr, copysize)

        return 0  # noErr
    catch
        # Return error if anything goes wrong
        return -1
    end
end

# ============================================================================
# Constructor
# ============================================================================

"""
    AudioProcessor(au::AudioUnit; max_channels=2, max_frames=4096, sample_rate=44100.0)

Create a new AudioProcessor for processing audio with the given AudioUnit.

# Arguments
- `au::AudioUnit`: The AudioUnit to process with (must be initialized)
- `max_channels::Int`: Maximum number of audio channels (default: 2)
- `max_frames::Int`: Maximum number of frames per process call (default: 4096)
- `sample_rate::Float64`: Sample rate in Hz (default: 44100.0)

# Returns
A new AudioProcessor ready for processing

# Throws
- `ErrorException` if the AudioUnit is not initialized
"""
function AudioProcessor(au::AudioUnit;
                       max_channels::Int=2,
                       max_frames::Int=4096,
                       sample_rate::Float64=44100.0)
    if !au.initialized
        error("AudioUnit must be initialized before creating AudioProcessor")
    end

    @assert max_channels > 0 "max_channels must be positive"
    @assert max_frames > 0 "max_frames must be positive"
    @assert sample_rate > 0 "sample_rate must be positive"

    # Pre-allocate buffers (persistent, never reallocated)
    buffer_list_size = 4 + max_channels * 16
    input_buffer_list = zeros(UInt8, buffer_list_size)
    output_buffer_list = zeros(UInt8, buffer_list_size)
    input_data = zeros(Float32, max_channels, max_frames)
    output_data = zeros(Float32, max_channels, max_frames)

    # Create callback (using module-level function, not closure!)
    callback_ptr = @cfunction(audio_render_callback, Int32,
                             (Ptr{Cvoid}, Ptr{UInt32}, Ptr{UInt8},
                              UInt32, UInt32, Ptr{UInt8}))

    callback_struct = zeros(UInt8, 2 * sizeof(Ptr{Cvoid}))

    processor = AudioProcessor(
        au, input_buffer_list, output_buffer_list,
        input_data, output_data,
        callback_ptr, callback_struct,
        max_channels, max_frames, sample_rate,
        buffer_list_size,
        false, false
    )

    return processor
end

# ============================================================================
# Public API: process() and process!()
# ============================================================================

"""
    process(processor::AudioProcessor, input) -> output

Process audio through the AudioProcessor, returning a new output buffer.

# Arguments
- `processor::AudioProcessor`: The processor to use
- `input`: Input audio buffer with a `.data` field (channels × samples) and `.samplerate` field
          (e.g., SampleBuf from SampledSignals.jl)

# Returns
A new audio buffer of the same type as input with the processed audio

# Throws
- `AssertionError` if input dimensions exceed processor's maximums
- `ErrorException` if audio rendering fails
"""
function process(processor::AudioProcessor, input)
    nchannels, nframes = size(input.data)

    # Validate dimensions
    @assert nchannels <= processor.max_channels "Input has $nchannels channels, processor supports max $(processor.max_channels)"
    @assert nframes <= processor.max_frames "Input has $nframes frames, processor supports max $(processor.max_frames)"
    @assert input.samplerate == processor.sample_rate "Sample rate mismatch: input has $(input.samplerate) Hz, processor expects $(processor.sample_rate) Hz"

    # Allocate output (same type as input)
    output_data = zeros(eltype(input.data), nchannels, nframes)

    # Process
    _process_internal!(processor, input.data, output_data, nchannels, nframes)

    return typeof(input)(output_data, input.samplerate)
end

"""
    process!(processor::AudioProcessor, input, output) -> output

Process audio in-place through the AudioProcessor, writing to the output buffer.

This is zero-allocation - reuse the same processor and buffers for streaming.

# Arguments
- `processor::AudioProcessor`: The processor to use
- `input`: Input audio buffer with `.data` (channels × samples) and `.samplerate` fields
- `output`: Pre-allocated output buffer (must match input size and sample rate)

# Returns
The output buffer (same object passed in, modified)

# Throws
- `AssertionError` if sizes don't match or exceed processor's maximums
- `ErrorException` if audio rendering fails
"""
function process!(processor::AudioProcessor, input, output)
    @assert size(input) == size(output) "Input size $(size(input)) and output size $(size(output)) don't match"
    @assert input.samplerate == output.samplerate "Input and output sample rates don't match"

    nchannels, nframes = size(input.data)

    _process_internal!(processor, input.data, output.data, nchannels, nframes)

    return output
end

# ============================================================================
# Internal implementation functions
# ============================================================================

"""Internal: Core processing logic"""
function _process_internal!(processor::AudioProcessor,
                           input_data,
                           output_data,
                           nchannels::Int,
                           nframes::Int)
    # Copy input to persistent buffer
    processor.input_data[1:nchannels, 1:nframes] .= input_data

    # Set up AudioBufferList pointers
    _setup_buffer_lists!(processor, nchannels, nframes)

    # Set callback (only on first call)
    if !processor.callback_set
        _set_render_callback!(processor)
        processor.callback_set = true
    end

    # Render audio (with GC.@preserve to keep processor alive)
    _render_audio!(processor, nchannels, nframes)

    # Copy output from persistent buffer
    output_data .= processor.output_data[1:nchannels, 1:nframes]
end

"""Internal: Set up AudioBufferList structures"""
function _setup_buffer_lists!(processor::AudioProcessor, nchannels::Int, nframes::Int)
    # Setup input buffer list
    unsafe_store!(Ptr{UInt32}(pointer(processor.input_buffer_list)), UInt32(nchannels))

    for ch in 1:nchannels
        offset = 4 + (ch - 1) * 16
        base = pointer(processor.input_buffer_list) + offset

        unsafe_store!(Ptr{UInt32}(base), UInt32(1))  # mNumberChannels
        unsafe_store!(Ptr{UInt32}(base + 4), UInt32(nframes * sizeof(Float32)))  # mDataByteSize

        # Point to persistent buffer (within processor.input_data)
        channel_ptr = pointer(processor.input_data, (ch-1) * processor.max_frames + 1)
        unsafe_store!(Ptr{Ptr{Cvoid}}(base + 8), channel_ptr)  # mData
    end

    # Setup output buffer list (similar)
    unsafe_store!(Ptr{UInt32}(pointer(processor.output_buffer_list)), UInt32(nchannels))

    for ch in 1:nchannels
        offset = 4 + (ch - 1) * 16
        base = pointer(processor.output_buffer_list) + offset

        unsafe_store!(Ptr{UInt32}(base), UInt32(1))  # mNumberChannels
        unsafe_store!(Ptr{UInt32}(base + 4), UInt32(nframes * sizeof(Float32)))  # mDataByteSize

        channel_ptr = pointer(processor.output_data, (ch-1) * processor.max_frames + 1)
        unsafe_store!(Ptr{Ptr{Cvoid}}(base + 8), channel_ptr)  # mData
    end
end

"""Internal: Set render callback on the AudioUnit"""
function _set_render_callback!(processor::AudioProcessor)
    # Store function pointer
    unsafe_store!(Ptr{Ptr{Cvoid}}(pointer(processor.callback_struct)),
                  Base.unsafe_convert(Ptr{Cvoid}, processor.callback_ptr))

    # Store pointer to processor itself (NOT just buffer!)
    processor_ptr = pointer_from_objref(processor)
    unsafe_store!(Ptr{Ptr{Cvoid}}(pointer(processor.callback_struct) + sizeof(Ptr{Cvoid})),
                  processor_ptr)

    # Set callback on AudioUnit
    status = ccall((:AudioUnitSetProperty, AudioToolbox), Int32,
                  (Ptr{Cvoid}, UInt32, UInt32, UInt32, Ptr{UInt8}, UInt32),
                  processor.au.instance,
                  UInt32(23),  # kAudioUnitProperty_SetRenderCallback
                  UInt32(1),   # kAudioUnitScope_Input
                  UInt32(0),   # element
                  processor.callback_struct,
                  UInt32(sizeof(processor.callback_struct)))

    if status != 0
        error("Failed to set render callback: OSStatus $status")
    end
end

"""Internal: Render audio using AudioUnitRender"""
function _render_audio!(processor::AudioProcessor, nchannels::Int, nframes::Int)
    # Set up timestamp structure
    timestamp = zeros(UInt8, 80)  # AudioTimeStamp is 80 bytes
    unsafe_store!(Ptr{Float64}(pointer(timestamp)), 0.0)  # mSampleTime
    unsafe_store!(Ptr{UInt32}(pointer(timestamp) + 8), UInt32(1))  # Flags

    action_flags = Ref{UInt32}(0)

    # CRITICAL: Use GC.@preserve to keep processor alive during render
    # This ensures the processor and all its buffers don't get garbage collected
    GC.@preserve processor begin
        status = ccall((:AudioUnitRender, AudioToolbox), Int32,
                      (Ptr{Cvoid}, Ptr{UInt32}, Ptr{UInt8}, UInt32, UInt32, Ptr{UInt8}),
                      processor.au.instance,
                      action_flags,
                      timestamp,
                      UInt32(0),  # inBusNumber
                      UInt32(nframes),
                      pointer(processor.output_buffer_list))

        if status != 0
            error("AudioUnitRender failed: OSStatus $status")
        end
    end
end

# ============================================================================
# Cleanup
# ============================================================================

"""
    dispose(processor::AudioProcessor)

Clean up the AudioProcessor and remove its render callback.

Call this when you're done processing to unregister the callback
and allow the processor to be garbage collected.

# Arguments
- `processor::AudioProcessor`: The processor to clean up
"""
function dispose(processor::AudioProcessor)
    if processor.callback_set
        # Remove callback by setting NULL
        null_struct = zeros(UInt8, 2 * sizeof(Ptr{Cvoid}))

        ccall((:AudioUnitSetProperty, AudioToolbox), Int32,
              (Ptr{Cvoid}, UInt32, UInt32, UInt32, Ptr{UInt8}, UInt32),
              processor.au.instance,
              UInt32(23),  # kAudioUnitProperty_SetRenderCallback
              UInt32(1),   # kAudioUnitScope_Input
              UInt32(0),   # element
              null_struct,
              UInt32(sizeof(null_struct)))

        processor.callback_set = false
    end

    processor.initialized = false
end
