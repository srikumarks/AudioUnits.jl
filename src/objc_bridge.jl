# ObjectiveC Bridge for AUv3 Integration
#
# This module provides all ObjectiveC.jl integration for AUv3 AudioUnit support.
# It handles framework imports, class references, and helper functions for
# converting between Objective-C and Julia types, managing async/sync conversions,
# and creating real-time safe Objective-C blocks.

using ObjectiveC

# ============================================================================
# Framework Imports
# ============================================================================

const AVFoundation = ObjectiveC.@framework "AVFoundation"
const AudioToolbox = ObjectiveC.@framework "AudioToolbox"

# ============================================================================
# ObjectiveC Class References
# ============================================================================

# Component Discovery
const AVAudioUnitComponentManager = ObjectiveC.@class AVAudioUnitComponentManager
const AVAudioUnitComponent = ObjectiveC.@class AVAudioUnitComponent

# Audio Units
const AUAudioUnit = ObjectiveC.@class AUAudioUnit
const AVAudioUnit = ObjectiveC.@class AVAudioUnit

# Parameters
const AUParameterTree = ObjectiveC.@class AUParameterTree
const AUParameterNode = ObjectiveC.@class AUParameterNode
const AUParameter = ObjectiveC.@class AUParameter

# Audio Engine
const AVAudioEngine = ObjectiveC.@class AVAudioEngine
const AVAudioNode = ObjectiveC.@class AVAudioNode
const AVAudioPlayerNode = ObjectiveC.@class AVAudioPlayerNode

# Buffers
const AVAudioPCMBuffer = ObjectiveC.@class AVAudioPCMBuffer
const AVAudioFormat = ObjectiveC.@class AVAudioFormat

# Foundation
const NSString = ObjectiveC.@class NSString
const NSArray = ObjectiveC.@class NSArray
const NSError = ObjectiveC.@class NSError
const NSNumber = ObjectiveC.@class NSNumber

# ============================================================================
# String Conversion Utilities
# ============================================================================

"""
    nsstring_to_julia(nsstr::ObjectiveC.Object) -> String

Convert an NSString to a Julia String.
"""
function nsstring_to_julia(nsstr::ObjectiveC.Object)
    if isnothing(nsstr) || isa(nsstr, Ptr) && nsstr == C_NULL
        return ""
    end

    # Get C string pointer from NSString
    c_str = ObjectiveC.msgSend(nsstr, "UTF8String", ObjectiveC.Ptr{Cchar})
    if c_str == C_NULL
        return ""
    end

    return unsafe_string(c_str)
end

"""
    julia_to_nsstring(str::String) -> ObjectiveC.Object

Convert a Julia String to an NSString.
"""
function julia_to_nsstring(str::String)
    return ObjectiveC.msgSend(NSString, "stringWithUTF8String:", str)
end

# ============================================================================
# Async-to-Sync Conversion
# ============================================================================

"""
    objc_await(async_func::Function) -> Any

Wrap an asynchronous Objective-C operation in a synchronous Julia API.

The `async_func` should take a single completion handler function as argument
and call it when the async operation completes.

Example:
    result = objc_await() do completion
        AUAudioUnit.instantiateWithComponentDescription_options_completionHandler(
            desc, 0, create_completion_block(completion)
        )
    end

This function:
1. Creates a completion handler
2. Calls async_func with the completion handler
3. Blocks Julia execution until completion
4. Returns the result or throws an error
"""
function objc_await(async_func::Function)
    result = Ref{Any}(nothing)
    error_ref = Ref{Any}(nothing)
    completed = Threads.Condition()

    # Create a Julia function to use as completion handler
    completion_handler = function(au::Any, err::Any)
        lock(completed) do
            if !isnothing(err) && err != C_NULL
                error_ref[] = err
            else
                result[] = au
            end
            notify(completed)
        end
    end

    # Call the async function with our completion handler
    try
        async_func(completion_handler)
    catch e
        rethrow(e)
    end

    # Wait for completion with timeout
    lock(completed) do
        # Wait with 30 second timeout
        wait_result = timedwait(completed, 30.0) do
            result[] !== nothing || error_ref[] !== nothing
        end

        if wait_result == :timed_out
            error("AUv3 instantiation timed out after 30 seconds")
        end
    end

    # Check for errors
    if !isnothing(error_ref[])
        err_obj = error_ref[]
        error_msg = "Unknown error"

        # Try to get error description
        if !isa(err_obj, Ptr) || err_obj != C_NULL
            try
                err_desc = ObjectiveC.msgSend(err_obj, "localizedDescription", ObjectiveC.Object)
                error_msg = nsstring_to_julia(err_desc)
            catch
            end
        end

        error("AUv3 instantiation failed: $error_msg")
    end

    return result[]
end

# ============================================================================
# Completion Block Creation
# ============================================================================

"""
    create_completion_block(handler::Function)

Create an Objective-C block for async instantiation completion.

The block signature is:
    ^(AUAudioUnit *au, NSError *error)
"""
function create_completion_block(handler::Function)
    # Create a closure block that calls the Julia handler
    # Block signature: void (^)(AUAudioUnit *, NSError *)
    block = ObjectiveC.@block (au::ObjectiveC.Object, err::ObjectiveC.Object) -> begin
        handler(au, err)
        return nothing
    end

    return block
end

# ============================================================================
# AudioComponentDescription Creation
# ============================================================================

"""
    create_audio_component_description(
        component_type::UInt32,
        component_subtype::UInt32,
        component_manufacturer::UInt32
    ) -> Vector{UInt8}

Create an AudioComponentDescription structure for component discovery.

Returns a byte vector containing the properly formatted AudioComponentDescription
that matches the C struct layout.
"""
function create_audio_component_description(
    component_type::UInt32,
    component_subtype::UInt32,
    component_manufacturer::UInt32 = 0
)
    # AudioComponentDescription layout (20 bytes):
    # componentType: UInt32
    # componentSubType: UInt32
    # componentManufacturer: UInt32
    # componentFlags: UInt32
    # componentFlagsMask: UInt32

    desc = Vector{UInt8}(undef, 20)

    # Write each field (little-endian)
    unsafe_store!(Ptr{UInt32}(pointer(desc)), component_type)
    unsafe_store!(Ptr{UInt32}(pointer(desc) + 4), component_subtype)
    unsafe_store!(Ptr{UInt32}(pointer(desc) + 8), component_manufacturer)
    unsafe_store!(Ptr{UInt32}(pointer(desc) + 12), UInt32(0))  # flags
    unsafe_store!(Ptr{UInt32}(pointer(desc) + 16), UInt32(0))  # flagsMask

    return desc
end

# ============================================================================
# Buffer List Management
# ============================================================================

"""
    create_audio_buffer_list(nchannels::Int, nbuffers::Int) -> Vector{UInt8}

Create an AudioBufferList structure for audio data.

Returns a byte vector containing the properly formatted AudioBufferList.
The structure is:
- mNumberBuffers: UInt32 (4 bytes)
- mBuffers: Array of AudioBuffer (nchannels * 16 bytes)

Total size: 4 + nchannels * 16
"""
function create_audio_buffer_list(nchannels::Int, nframes::Int)
    buffer_list_size = 4 + nchannels * 16
    buffer_list = zeros(UInt8, buffer_list_size)

    # Set number of buffers (first 4 bytes, little-endian UInt32)
    unsafe_store!(Ptr{UInt32}(pointer(buffer_list)), UInt32(nchannels))

    return buffer_list
end

"""
    setup_audio_buffer!(
        buffer_list::Vector{UInt8},
        channel_idx::Int,
        data::Vector{Float32}
    )

Configure an AudioBuffer within an AudioBufferList to point to audio data.

Parameters:
- buffer_list: The AudioBufferList structure
- channel_idx: Which channel buffer to configure (0-based)
- data: Vector of Float32 audio samples
"""
function setup_audio_buffer!(
    buffer_list::Vector{UInt8},
    channel_idx::Int,
    data::Vector{Float32}
)
    # AudioBufferList layout:
    # [0:4] mNumberBuffers (UInt32)
    # [4:] mBuffers array (each is 16 bytes: mNumberChannels + mDataByteSize + mData)

    # Calculate offset for this buffer's AudioBuffer structure
    buffer_offset = 4 + channel_idx * 16

    # Set mNumberChannels = 1 (single channel per buffer)
    unsafe_store!(Ptr{UInt32}(pointer(buffer_list) + buffer_offset), UInt32(1))

    # Set mDataByteSize
    nbytes = length(data) * sizeof(Float32)
    unsafe_store!(Ptr{UInt32}(pointer(buffer_list) + buffer_offset + 4), UInt32(nbytes))

    # Set mData pointer
    data_ptr = pointer(data)
    unsafe_store!(Ptr{Ptr{Cvoid}}(pointer(buffer_list) + buffer_offset + 8),
                 convert(Ptr{Cvoid}, data_ptr))
end

# ============================================================================
# AudioTimeStamp Creation
# ============================================================================

"""
    create_audio_timestamp(sample_time::Float64, sample_rate::Float64)

Create an AudioTimeStamp structure for render callbacks.

Returns a byte vector containing the properly formatted AudioTimeStamp.
"""
function create_audio_timestamp(sample_time::Float64, sample_rate::Float64)
    # AudioTimeStamp structure (56 bytes minimum)
    # mSampleTime (Float64): 8 bytes
    # mHostTime (UInt64): 8 bytes
    # mRateScalar (Float64): 8 bytes
    # mFlags (UInt32): 4 bytes
    # (+ 24 bytes reserved for alignment)

    timestamp = zeros(UInt8, 56)

    # Set mSampleTime
    unsafe_store!(Ptr{Float64}(pointer(timestamp)), sample_time)

    # Set mHostTime to current time (approximate)
    host_time = time_ns() ÷ 1000  # Convert to microseconds
    unsafe_store!(Ptr{UInt64}(pointer(timestamp) + 8), UInt64(host_time))

    # Set mRateScalar = 1.0
    unsafe_store!(Ptr{Float64}(pointer(timestamp) + 16), 1.0)

    # Set mFlags = 0x0F (all time fields are valid)
    unsafe_store!(Ptr{UInt32}(pointer(timestamp) + 24), UInt32(0x0F))

    return timestamp
end

# ============================================================================
# Utility Functions
# ============================================================================

"""
    objc_array_to_julia(objc_array::ObjectiveC.Object) -> Vector

Convert an NSArray to a Julia Vector.
"""
function objc_array_to_julia(objc_array::ObjectiveC.Object)
    if isnothing(objc_array) || objc_array == C_NULL
        return []
    end

    count = ObjectiveC.msgSend(objc_array, "count", UInt)
    result = Any[]

    for i in 0:(count-1)
        obj = ObjectiveC.msgSend(objc_array, "objectAtIndex:", UInt(i), ObjectiveC.Object)
        push!(result, obj)
    end

    return result
end

"""
    get_nserror_description(error::ObjectiveC.Object) -> String

Extract error description from an NSError object.
"""
function get_nserror_description(error::ObjectiveC.Object)
    if isnothing(error) || error == C_NULL
        return "Unknown error"
    end

    try
        desc = ObjectiveC.msgSend(error, "localizedDescription", ObjectiveC.Object)
        return nsstring_to_julia(desc)
    catch
        return "Unknown error"
    end
end

"""
    get_nserror_code(error::ObjectiveC.Object) -> Int

Extract error code from an NSError object.
"""
function get_nserror_code(error::ObjectiveC.Object)
    if isnothing(error) || error == C_NULL
        return -1
    end

    try
        code = ObjectiveC.msgSend(error, "code", Int)
        return code
    catch
        return -1
    end
end

# ============================================================================
# Selector and Message Sending Utilities
# ============================================================================

"""
    send_objc_message(obj::ObjectiveC.Object, selector::String, args...) -> Any

Send an Objective-C message (method call) to an object.

This is a convenience wrapper around ObjectiveC.msgSend for cleaner syntax.

Example:
    result = send_objc_message(manager, "componentsMatchingDescription:", desc)
"""
function send_objc_message(obj::ObjectiveC.Object, selector::String, args...)
    return ObjectiveC.msgSend(obj, selector, args...)
end

end  # module objc_bridge
