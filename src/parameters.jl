# AudioUnit parameter management for AUv3

"""
    parameters(au::AudioUnit; scope::UInt32 = kAudioUnitScope_Global) -> Vector{AudioUnitParameter}

Get all parameters for an AudioUnit by traversing the parameter tree.

For AUv3, parameters are organized in a hierarchical tree structure with groups
and individual parameters. This function flattens the tree and returns all parameters.

# Arguments
- `au::AudioUnit`: The AudioUnit instance (must be initialized first)
- `scope::UInt32`: For compatibility (AUv3 doesn't use scopes, included for API consistency)

# Returns
A vector of `AudioUnitParameter` objects containing parameter information.

# Examples
```julia
au = load("AULowpass")
initialize(au)

params = parameters(au)

for param in params
    println("Parameter: ", param.info.name)
    println("  Range: ", param.info.min_value, " to ", param.info.max_value)
    println("  Default: ", param.info.default_value)
end
```
"""
function parameters(au::AudioUnit; scope::UInt32 = kAudioUnitScope_Global)
    if !au.initialized
        error("AudioUnit must be initialized before accessing parameters")
    end

    if isnothing(au.parameter_tree) || au.parameter_tree == nil
        @debug "Parameter tree is null, returning empty parameter list"
        return AudioUnitParameter[]
    end

    params = AudioUnitParameter[]

    # Recursively traverse parameter tree
    traverse_parameter_tree(au.parameter_tree, params, scope)

    return params
end

"""
    parameterinfo(au::AudioUnit, param_id::UInt32, scope::UInt32 = kAudioUnitScope_Global) -> Union{AudioUnitParameterInfo, Nothing}

Get detailed information about a specific parameter by its address (ID).

For AUv3, parameters are identified by address (which matches the parameter ID).
"""
function parameterinfo(au::AudioUnit, param_id::UInt32,
                      scope::UInt32 = kAudioUnitScope_Global)
    if !au.initialized
        error("AudioUnit must be initialized before accessing parameters")
    end

    if isnothing(au.parameter_tree) || au.parameter_tree == nil
        return nothing
    end

    # Find parameter by address
    addr = UInt64(param_id)
    param = @objc [au.parameter_tree::id{AUParameterTree} parameterWithAddress:addr::UInt64]::id{AUParameter}

    if isnothing(param) || param == nil
        return nothing
    end

    # Extract parameter info
    return extract_parameter_info(param)
end

"""
    parametervalue(au::AudioUnit, param_id::UInt32; scope::UInt32 = kAudioUnitScope_Global, element::UInt32 = 0, offset::UInt32 = 0) -> Float32

Get the current value of a parameter.

In AUv3, all parameters are accessed via the parameter tree. The scope and element
parameters are included for API compatibility but are not used (AUv3 uses address-based access).

# Arguments
- `au::AudioUnit`: The AudioUnit instance
- `param_id::UInt32`: The parameter address/ID
- `scope::UInt32`: For compatibility (not used in AUv3)
- `element::UInt32`: For compatibility (not used in AUv3)
- `offset::UInt32`: For compatibility (not used in AUv3)

# Examples
```julia
value = parametervalue(au, param_id)
```
"""
function parametervalue(au::AudioUnit, param_id::UInt32;
                       scope = kAudioUnitScope_Global,
                       element = 0,
                       offset = 0)
    if !au.initialized
        error("AudioUnit must be initialized before accessing parameters")
    end

    if isnothing(au.parameter_tree) || au.parameter_tree == nil
        error("Parameter tree is null")
    end

    # Find parameter by address
    addr = UInt64(param_id)
    param = @objc [au.parameter_tree::id{AUParameterTree} parameterWithAddress:addr::UInt64]::id{AUParameter}

    if isnothing(param) || param == nil
        error("Parameter with address $param_id not found")
    end

    # Get parameter value
    value = @objc [param::id{AUParameter} value]::Float32

    return Float32(value)
end

"""
    setparametervalue!(au::AudioUnit, param_id::UInt32, value::Real; scope::UInt32 = kAudioUnitScope_Global, element::UInt32 = 0, offset::UInt32 = 0) -> Bool

Set the value of a parameter.

Returns `true` on success, `false` otherwise.

# Arguments
- `au::AudioUnit`: The AudioUnit instance
- `param_id::UInt32`: The parameter address/ID
- `value::Real`: The parameter value to set
- `scope::UInt32`: For compatibility (not used in AUv3)
- `element::UInt32`: For compatibility (not used in AUv3)
- `offset::UInt32`: For compatibility (not used in AUv3)

# Examples
```julia
# Set parameter to 0.5
setparametervalue!(au, param_id, 0.5)
```
"""
function setparametervalue!(au::AudioUnit, param_id::UInt32, value::Real;
                           scope = kAudioUnitScope_Global,
                           element = 0,
                           offset = 0)
    if !au.initialized
        error("AudioUnit must be initialized before setting parameters")
    end

    if isnothing(au.parameter_tree) || au.parameter_tree == nil
        @error "Parameter tree is null"
        return false
    end

    try
        # Find parameter by address
        addr = UInt64(param_id)
        param = @objc [au.parameter_tree::id{AUParameterTree} parameterWithAddress:addr::UInt64]::id{AUParameter}

        if isnothing(param) || param == nil
            @error "Parameter with address $param_id not found"
            return false
        end

        # Clamp value to parameter range
        min_val = @objc [param::id{AUParameter} minValue]::Float32
        max_val = @objc [param::id{AUParameter} maxValue]::Float32
        clamped_value = clamp(Float32(value), min_val, max_val)

        # Set the parameter value via the parameter's setValue method
        @objc [param::id{AUParameter} setValue:clamped_value::Float32]::Nothing

        return true
    catch e
        @error "Failed to set parameter value: $e"
        return false
    end
end

# ============================================================================
# Helper Functions
# ============================================================================

"""
    traverse_parameter_tree(node::ObjectiveC.Object, params::Vector{AudioUnitParameter}, scope::UInt32)

Recursively traverse the AUParameterTree and collect all parameters.

The tree structure can have parameter groups (like AUParameterGroup) containing
individual parameters (AUParameter). This function recursively explores the tree.
"""
function traverse_parameter_tree(node, params::Vector{AudioUnitParameter}, scope::UInt32)
    if isnothing(node) || node == nil
        return
    end

    try
        # Get children of this node
        children = @objc [node::id{AUParameterNode} children]::id{NSArray}

        if isnothing(children) || children == nil
            return
        end

        # Convert to Julia array
        children_array = objc_array_to_julia(children)

        for child in children_array
            if isnothing(child) || child == nil
                continue
            end

            try
                # Check if this is a parameter or a group using respondsToSelector
                # AUParameter responds to 'value', AUParameterGroup does not
                value_selector = sel"value"
                responds = @objc [child::id{Object} respondsToSelector:value_selector::Ptr{Cvoid}]::Bool

                if responds
                    # This is an AUParameter - extract info and add to list
                    try
                        address = @objc [child::id{AUParameter} address]::UInt64
                        info = extract_parameter_info(child)

                        if !isnothing(info)
                            push!(params, AudioUnitParameter(
                                UInt32(address),
                                scope,
                                0,
                                info
                            ))
                        end
                    catch e
                        @debug "Failed to extract parameter info: $e"
                    end
                else
                    # This is a group, recursively traverse it
                    traverse_parameter_tree(child, params, scope)
                end
            catch e
                @debug "Error processing parameter tree node: $e"
                continue
            end
        end
    catch e
        @debug "Error traversing parameter tree: $e"
    end
end

"""
    extract_parameter_info(param) -> Union{AudioUnitParameterInfo, Nothing}

Extract detailed information from an AUParameter object.
"""
function extract_parameter_info(param)
    if isnothing(param) || param == nil
        return nothing
    end

    try
        # Get parameter name
        display_name_obj = @objc [param::id{AUParameter} displayName]::id{NSString}
        name = nsstring_to_julia(display_name_obj)

        if isempty(name)
            name_obj = @objc [param::id{AUParameter} identifier]::id{NSString}
            name = nsstring_to_julia(name_obj)
        end

        # Get parameter unit and unit name
        unit_obj = @objc [param::id{AUParameter} unit]::UInt32
        unit_name = parameter_unit_to_string(unit_obj)

        # Get parameter range values
        min_value = @objc [param::id{AUParameter} minValue]::Float32
        max_value = @objc [param::id{AUParameter} maxValue]::Float32

        # Get current value (as default)
        current_value = @objc [param::id{AUParameter} value]::Float32

        # Get flags
        flags = @objc [param::id{AUParameter} flags]::UInt32

        return AudioUnitParameterInfo(
            name,
            unit_name,
            Float32(min_value),
            Float32(max_value),
            Float32(current_value),
            UInt32(flags)
        )
    catch e
        @debug "Failed to extract parameter info: $e"
        return nothing
    end
end

"""
    parameter_unit_to_string(unit::UInt32) -> String

Convert a parameter unit code to a human-readable string.
"""
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
