# AudioUnit parameter management

"""
    get_parameters(au::AudioUnit; scope::UInt32 = kAudioUnitScope_Global) -> Vector{AudioUnitParameter}

Get all parameters for an AudioUnit in the specified scope.

# Arguments
- `au::AudioUnit`: The AudioUnit instance
- `scope::UInt32`: The parameter scope (default: Global)

# Returns
A vector of `AudioUnitParameter` objects containing parameter information.

# Examples
```julia
au = load_audiounit("AULowpass")
params = get_parameters(au)

for param in params
    println("Parameter: ", param.info.name)
    println("  Range: ", param.info.min_value, " to ", param.info.max_value)
    println("  Default: ", param.info.default_value)
end
```
"""
function get_parameters(au::AudioUnit; scope::UInt32 = kAudioUnitScope_Global)
    # Get parameter list
    param_ids = get_parameter_list(au.instance, scope)

    parameters = AudioUnitParameter[]

    for param_id in param_ids
        info = get_parameter_info(au, param_id, scope)
        if !isnothing(info)
            push!(parameters, AudioUnitParameter(param_id, scope, 0, info))
        end
    end

    return parameters
end

"""
    get_parameter_info(au::AudioUnit, param_id::UInt32, scope::UInt32 = kAudioUnitScope_Global) -> Union{AudioUnitParameterInfo, Nothing}

Get detailed information about a specific parameter.
"""
function get_parameter_info(au::AudioUnit, param_id::UInt32,
                           scope::UInt32 = kAudioUnitScope_Global)
    # AudioUnitParameterInfo structure in C
    # We'll use a buffer to receive the data
    info_size = Ref{UInt32}(256)  # Size of buffer
    info_buffer = zeros(UInt8, 256)

    status = ccall((:AudioUnitGetProperty, AudioToolbox), Int32,
                  (Ptr{Cvoid}, UInt32, UInt32, UInt32, Ptr{UInt8}, Ptr{UInt32}),
                  au.instance, kAudioUnitProperty_ParameterInfo,
                  scope, param_id, info_buffer, info_size)

    if status != noErr
        return nothing
    end

    # Parse the parameter info structure
    # struct AudioUnitParameterInfo {
    #   char name[52];
    #   CFStringRef unitName;
    #   UInt32 clumpID;
    #   CFStringRef cfNameString;
    #   AudioUnitParameterUnit unit;
    #   AudioUnitParameterValue minValue;
    #   AudioUnitParameterValue maxValue;
    #   AudioUnitParameterValue defaultValue;
    #   UInt32 flags;
    # }

    ptr = pointer(info_buffer)

    # Read name (52 bytes, null-terminated C string)
    name_bytes = unsafe_wrap(Array, Ptr{UInt8}(ptr), 52)
    null_idx = findfirst(==(0), name_bytes)
    name = if isnothing(null_idx)
        String(name_bytes)
    else
        String(name_bytes[1:null_idx-1])
    end

    # Skip to minValue (after name[52], unitName ptr, clumpID, cfNameString ptr, unit)
    # 52 + 8 + 4 + 8 + 4 = 76 bytes
    offset = 52 + sizeof(Ptr{Cvoid}) + 4 + sizeof(Ptr{Cvoid}) + 4

    min_value = unsafe_load(Ptr{Float32}(ptr + offset))
    max_value = unsafe_load(Ptr{Float32}(ptr + offset + 4))
    default_value = unsafe_load(Ptr{Float32}(ptr + offset + 8))
    flags = unsafe_load(Ptr{UInt32}(ptr + offset + 12))

    # Get unit name from the unit field
    unit = unsafe_load(Ptr{UInt32}(ptr + 52 + sizeof(Ptr{Cvoid}) + 4 + sizeof(Ptr{Cvoid})))
    unit_name = parameter_unit_to_string(unit)

    return AudioUnitParameterInfo(name, unit_name, min_value, max_value, default_value, flags)
end

"""
    get_parameter_value(au::AudioUnit, param_id::UInt32; scope::UInt32 = kAudioUnitScope_Global, element::UInt32 = 0) -> Float32

Get the current value of a parameter.

# Examples
```julia
value = get_parameter_value(au, param_id)
```
"""
function get_parameter_value(au::AudioUnit, param_id::UInt32;
                            scope::UInt32 = kAudioUnitScope_Global,
                            element::UInt32 = 0)
    value = Ref{Float32}()

    status = ccall((:AudioUnitGetParameter, AudioToolbox), Int32,
                  (Ptr{Cvoid}, UInt32, UInt32, UInt32, Ptr{Float32}),
                  au.instance, param_id, scope, element, value)

    if status != noErr
        error("Failed to get parameter value: OSStatus $status")
    end

    return value[]
end

"""
    set_parameter_value(au::AudioUnit, param_id::UInt32, value::Real; scope::UInt32 = kAudioUnitScope_Global, element::UInt32 = 0) -> Bool

Set the value of a parameter.

Returns `true` on success, `false` otherwise.

# Examples
```julia
# Set parameter to 0.5
set_parameter_value(au, param_id, 0.5)
```
"""
function set_parameter_value(au::AudioUnit, param_id::UInt32, value::Real;
                            scope::UInt32 = kAudioUnitScope_Global,
                            element::UInt32 = 0)
    status = ccall((:AudioUnitSetParameter, AudioToolbox), Int32,
                  (Ptr{Cvoid}, UInt32, UInt32, UInt32, Float32, UInt32),
                  au.instance, param_id, scope, element, Float32(value), 0)

    if status != noErr
        @error "Failed to set parameter value: OSStatus $status"
        return false
    end

    return true
end

# Helper functions

function get_parameter_list(instance::Ptr{Cvoid}, scope::UInt32)
    # Get the size of the parameter list
    size = Ref{UInt32}(0)
    writable = Ref{UInt32}(0)

    status = ccall((:AudioUnitGetPropertyInfo, AudioToolbox), Int32,
                  (Ptr{Cvoid}, UInt32, UInt32, UInt32, Ptr{UInt32}, Ptr{UInt32}),
                  instance, kAudioUnitProperty_ParameterList,
                  scope, 0, size, writable)

    if status != noErr || size[] == 0
        return UInt32[]
    end

    # Allocate buffer and get parameter list
    num_params = size[] ÷ sizeof(UInt32)
    param_ids = zeros(UInt32, num_params)

    status = ccall((:AudioUnitGetProperty, AudioToolbox), Int32,
                  (Ptr{Cvoid}, UInt32, UInt32, UInt32, Ptr{UInt32}, Ptr{UInt32}),
                  instance, kAudioUnitProperty_ParameterList,
                  scope, 0, param_ids, size)

    if status != noErr
        return UInt32[]
    end

    return param_ids
end

function parameter_unit_to_string(unit::UInt32)::String
    unit_names = Dict(
        kAudioUnitParameterUnit_Generic => "Generic",
        kAudioUnitParameterUnit_Indexed => "Indexed",
        kAudioUnitParameterUnit_Boolean => "Boolean",
        kAudioUnitParameterUnit_Percent => "Percent",
        kAudioUnitParameterUnit_Seconds => "Seconds",
        kAudioUnitParameterUnit_SampleFrames => "Samples",
        kAudioUnitParameterUnit_Phase => "Phase",
        kAudioUnitParameterUnit_Rate => "Rate",
        kAudioUnitParameterUnit_Hertz => "Hz",
        kAudioUnitParameterUnit_Cents => "Cents",
        kAudioUnitParameterUnit_RelativeSemiTones => "Semitones",
        kAudioUnitParameterUnit_MIDINoteNumber => "MIDI Note",
        kAudioUnitParameterUnit_MIDIController => "MIDI CC",
        kAudioUnitParameterUnit_Decibels => "dB",
        kAudioUnitParameterUnit_LinearGain => "Linear Gain",
        kAudioUnitParameterUnit_Degrees => "Degrees",
        kAudioUnitParameterUnit_EqualPowerCrossfade => "Equal Power",
        kAudioUnitParameterUnit_MixerFaderCurve1 => "Fader Curve",
        kAudioUnitParameterUnit_Pan => "Pan",
        kAudioUnitParameterUnit_Meters => "Meters",
        kAudioUnitParameterUnit_AbsoluteCents => "Absolute Cents",
        kAudioUnitParameterUnit_Octaves => "Octaves",
        kAudioUnitParameterUnit_BPM => "BPM",
        kAudioUnitParameterUnit_Beats => "Beats",
        kAudioUnitParameterUnit_Milliseconds => "ms",
        kAudioUnitParameterUnit_Ratio => "Ratio"
    )

    return get(unit_names, unit, "Unknown")
end
