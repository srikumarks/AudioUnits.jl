# ObjectiveC Bridge for AUv3 Integration
#
# This module provides ObjectiveC.jl v3 integration for AUv3 AudioUnit support.
# Based on ObjectiveC.jl v3.4.2 API from https://github.com/JuliaInterop/ObjectiveC.jl

using ObjectiveC
using ObjectiveC.Foundation
using ObjectiveC.CoreFoundation

# ============================================================================
# Objective-C Class Wrapper Definitions
# ============================================================================

# Create wrapper types for AUv3 classes using @objcwrapper
@objcwrapper AVAudioEngine <: NSObject
@objcwrapper AVAudioNode <: NSObject
@objcwrapper AVAudioUnit <: AVAudioNode
@objcwrapper AVAudioUnitComponentManager <: NSObject
@objcwrapper AVAudioUnitComponent <: NSObject
@objcwrapper AUAudioUnit <: NSObject
@objcwrapper AUParameterTree <: NSObject
@objcwrapper AUParameterNode <: NSObject
@objcwrapper AUParameter <: AUParameterNode
@objcwrapper AVAudioPlayerNode <: AVAudioNode
@objcwrapper AVAudioPCMBuffer <: NSObject
@objcwrapper AVAudioFormat <: NSObject

# ============================================================================
# Helper Functions for Message Sending
# ============================================================================

"""
    msgSend(receiver, selector, args...; return_type=id{Object})

Send an Objective-C message using ObjectiveC.jl v3's @objc macro.

This is a compatibility shim for code that expects msgSend-style calls.
In ObjectiveC.jl v3, you should use @objc [...] directly.

# Examples
```julia
# Get shared component manager
manager = msgSend(AVAudioUnitComponentManager, "sharedAudioUnitComponentManager",
                 return_type=id{AVAudioUnitComponentManager})
```
"""
function msgSend(receiver, selector::String, args...; return_type=id{Object})
    # This is a simplified shim - actual implementation would need to parse
    # selector and args to construct proper @objc call
    # For now, we handle common patterns

    if isempty(args)
        # Simple selector with no arguments
        sel = Symbol(selector)
        return eval(:(@objc [$receiver::id{Object} $sel]::$return_type))
    else
        error("msgSend with arguments not yet fully implemented - use @objc macro directly")
    end
end

# ============================================================================
# String Conversion Utilities
# ============================================================================

"""
    nsstring_to_julia(nsstr::id{NSString}) -> String

Convert an NSString to a Julia String using Foundation.
"""
function nsstring_to_julia(nsstr)
    if isnothing(nsstr) || nsstr == nil
        return ""
    end

    # Wrap in Foundation.NSString if needed
    str = isa(nsstr, Foundation.NSString) ? nsstr : Foundation.NSString(nsstr)
    return String(str)
end

"""
    julia_to_nsstring(str::String) -> Foundation.NSString

Convert a Julia String to an NSString.
"""
function julia_to_nsstring(str::String)
    return Foundation.NSString(str)
end

# ============================================================================
# Array Conversion Utilities
# ============================================================================

"""
    objc_array_to_julia(objc_array::id{NSArray}) -> Vector

Convert an NSArray to a Julia Vector.
"""
function objc_array_to_julia(objc_array)
    if isnothing(objc_array) || objc_array == nil
        return []
    end

    # Get count
    count = @objc [objc_array::id{NSArray} count]::UInt

    result = Any[]
    for i in 0:(count-1)
        idx = UInt(i)
        obj = @objc [objc_array::id{NSArray} objectAtIndex:idx::UInt]::id{Object}
        push!(result, obj)
    end

    return result
end

"""
    julia_to_nsarray(arr::Vector) -> Foundation.NSArray

Convert a Julia Vector to an NSArray.
"""
function julia_to_nsarray(arr::Vector)
    return Foundation.NSArray(arr)
end

# ============================================================================
# Error Handling Utilities
# ============================================================================

"""
    get_nserror_description(error::id{NSError}) -> String

Extract error description from an NSError object.
"""
function get_nserror_description(error)
    if isnothing(error) || error == nil
        return "Unknown error"
    end

    try
        desc = @objc [error::id{NSError} localizedDescription]::id{NSString}
        return nsstring_to_julia(desc)
    catch e
        return "Error getting description: $e"
    end
end

"""
    get_nserror_code(error::id{NSError}) -> Int

Extract error code from an NSError object.
"""
function get_nserror_code(error)
    if isnothing(error) || error == nil
        return -1
    end

    try
        return @objc [error::id{NSError} code]::Int
    catch
        return -1
    end
end

# ============================================================================
# Async-to-Sync Conversion
# ============================================================================

"""
    objc_await(async_func::Function) -> Any

Wrap an asynchronous Objective-C operation in a synchronous Julia API.

Uses Threads.Condition to block Julia execution until the completion handler fires.

# Example
```julia
result = objc_await() do completion_handler
    # Create completion block
    block = @objcblock (au, err) -> begin
        completion_handler(au, err)
    end (Nothing, (id{AUAudioUnit}, id{NSError}))

    # Call async method
    @objc [AUAudioUnit instantiateWithComponentDescription:desc::id{...}
                       options:$(UInt32(0))::UInt32
                       completionHandler:block::id{Object}]::Nothing
end
```
"""
function objc_await(async_func::Function)
    result = Ref{Any}(nothing)
    error_ref = Ref{Any}(nothing)
    completed = Threads.Condition()

    # Create completion handler
    completion_handler = function(au::Any, err::Any)
        lock(completed) do
            if !isnothing(err) && err != nil
                error_ref[] = err
            else
                result[] = au
            end
            notify(completed)
        end
    end

    # Call async function with completion handler
    try
        async_func(completion_handler)
    catch e
        rethrow(e)
    end

    # Wait for completion with timeout
    wait_result = timedwait(30.0) do
        result[] !== nothing || error_ref[] !== nothing
    end

    if wait_result == :timed_out
        error("AUv3 instantiation timed out after 30 seconds")
    end

    # Check for errors
    if !isnothing(error_ref[])
        err_msg = get_nserror_description(error_ref[])
        error("AUv3 operation failed: $err_msg")
    end

    return result[]
end

# ============================================================================
# AudioComponentDescription Creation
# ============================================================================

"""
    create_audio_component_description(type, subtype, manufacturer) -> AudioComponentDescription

Create an AudioComponentDescription structure for component discovery.

Returns a properly structured AudioComponentDescription with:
- componentType: UInt32
- componentSubType: UInt32
- componentManufacturer: UInt32
- componentFlags: UInt32 (0)
- componentFlagsMask: UInt32 (0)
"""
function create_audio_component_description(
    component_type::UInt32,
    component_subtype::UInt32,
    component_manufacturer::UInt32 = UInt32(0)
)
    return AudioComponentDescription(
        component_type,
        component_subtype,
        component_manufacturer,
        UInt32(0),  # flags
        UInt32(0)   # flagsMask
    )
end

# ============================================================================
# Buffer Management
# ============================================================================

"""
    create_audio_buffer_list(nchannels::Int, nframes::Int) -> Vector{UInt8}

Create an AudioBufferList structure for audio data.

Structure:
- mNumberBuffers: UInt32 (4 bytes)
- mBuffers: Array of AudioBuffer (nchannels * 16 bytes)

Total size: 4 + nchannels * 16
"""
function create_audio_buffer_list(nchannels::Int, nframes::Int)
    buffer_list_size = 4 + nchannels * 16
    buffer_list = zeros(UInt8, buffer_list_size)

    unsafe_store!(Ptr{UInt32}(pointer(buffer_list)), UInt32(nchannels))

    return buffer_list
end

"""
    setup_audio_buffer!(buffer_list, channel_idx, data)

Configure an AudioBuffer within an AudioBufferList to point to audio data.

AudioBuffer structure (16 bytes):
- mNumberChannels: UInt32
- mDataByteSize: UInt32
- mData: Ptr{Cvoid}
"""
function setup_audio_buffer!(
    buffer_list::Vector{UInt8},
    channel_idx::Int,
    data::Vector{Float32}
)
    buffer_offset = 4 + channel_idx * 16

    # Set mNumberChannels = 1
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
    create_audio_timestamp(sample_time::Float64, sample_rate::Float64) -> Vector{UInt8}

Create an AudioTimeStamp structure for render callbacks.

Structure (64 bytes):
- mSampleTime: Float64 (8 bytes) - offset 0
- mHostTime: UInt64 (8 bytes) - offset 8
- mRateScalar: Float64 (8 bytes) - offset 16
- mWordClockTime: UInt64 (8 bytes) - offset 24
- mSMPTETime: SMPTETime (24 bytes) - offset 32
- mFlags: UInt32 (4 bytes) - offset 56
- mReserved: UInt32 (4 bytes) - offset 60
"""
function create_audio_timestamp(sample_time::Float64, sample_rate::Float64)
    timestamp = zeros(UInt8, 64)

    # Set mSampleTime
    unsafe_store!(Ptr{Float64}(pointer(timestamp)), sample_time)

    # Set mHostTime to current time (use mach_absolute_time equivalent)
    host_time = time_ns()
    unsafe_store!(Ptr{UInt64}(pointer(timestamp) + 8), UInt64(host_time))

    # Set mRateScalar = 1.0
    unsafe_store!(Ptr{Float64}(pointer(timestamp) + 16), 1.0)

    # mWordClockTime at offset 24 - leave as 0
    # mSMPTETime at offset 32 - leave as 0

    # Set mFlags at offset 56
    # kAudioTimeStampSampleTimeValid = 0x1
    # kAudioTimeStampHostTimeValid = 0x2
    # kAudioTimeStampRateScalarValid = 0x4
    unsafe_store!(Ptr{UInt32}(pointer(timestamp) + 56), UInt32(0x07))

    return timestamp
end

# ============================================================================
# Utility Functions
# ============================================================================

"""
    fourcc_to_string(code::UInt32) -> String

Convert a FourCC code to a readable string.
"""
function fourcc_to_string(code::UInt32)
    bytes = reinterpret(UInt8, [code])
    chars = Char[Char(bytes[4]), Char(bytes[3]), Char(bytes[2]), Char(bytes[1])]
    return String(chars)
end
