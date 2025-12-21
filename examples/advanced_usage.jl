# Advanced usage examples for AudioUnits.jl

using AudioUnits

println("AudioUnits.jl - Advanced Usage Examples")
println("=" ^ 70)
println()

# Example 1: Initialize an AudioUnit and manipulate parameters
println("Example 1: Parameter manipulation")
println("-" ^ 70)

try
    # Load an effect (adjust name as needed for your system)
    au = load_audiounit("AULowpass")
    println("Loaded: ", au.name)

    # Initialize the AudioUnit
    if initialize_audiounit(au)
        println("AudioUnit initialized successfully")

        # Get parameters
        params = get_parameters(au)

        if !isempty(params)
            # Work with the first parameter
            param = params[1]
            println()
            println("Working with parameter: ", param.info.name)

            # Get current value
            current_val = get_parameter_value(au, param.id)
            println("  Current value: ", current_val)

            # Set to midpoint
            mid_val = (param.info.min_value + param.info.max_value) / 2
            if set_parameter_value(au, param.id, mid_val)
                println("  Set to midpoint: ", mid_val)
                new_val = get_parameter_value(au, param.id)
                println("  New value: ", new_val)
            end

            # Restore original value
            set_parameter_value(au, param.id, current_val)
            println("  Restored to: ", current_val)
        end

        # Uninitialize before disposal
        uninitialize_audiounit(au)
        println()
        println("AudioUnit uninitialized")
    end

    dispose_audiounit(au)
    println("AudioUnit disposed")

catch e
    println("Error: ", e)
end

println()

# Example 2: Check capabilities
println("Example 2: Capability detection")
println("-" ^ 70)

# Find and analyze different types of AudioUnits
for au_type in [kAudioUnitType_Effect, kAudioUnitType_MusicDevice]
    units = find_audiounits(au_type)

    if !isempty(units)
        println()
        println("Analyzing: ", units[1].name)

        try
            au = load_audiounit(units[1].type, units[1].subtype)

            println("  Effects processing: ", supports_effects(au))
            println("  MIDI input: ", supports_midi(au))
            println("  Can bypass: ", can_bypass(au))

            # Channel configurations
            configs = get_channel_capabilities(au)
            println("  Channel configs: ", length(configs))
            for config in configs
                in_ch = config.input_channels < 0 ? "any" : string(config.input_channels)
                out_ch = config.output_channels < 0 ? "any" : string(config.output_channels)
                println("    In: ", in_ch, ", Out: ", out_ch)
            end

            dispose_audiounit(au)
        catch e
            println("  Could not load: ", e)
        end
    end
end

println()

# Example 3: Generate comprehensive documentation
println("Example 3: Documentation generation")
println("-" ^ 70)

try
    # Load an AudioUnit
    units = find_audiounits(kAudioUnitType_Effect)

    if !isempty(units)
        au = load_audiounit(units[1].type, units[1].subtype)
        initialize_audiounit(au)

        # Generate and display documentation
        doc = get_documentation(au)
        println(doc)

        uninitialize_audiounit(au)
        dispose_audiounit(au)
    else
        println("No effect units found on this system")
    end

catch e
    println("Error: ", e)
end

println()

# Example 4: Bypass mode demonstration
println("Example 4: Bypass mode")
println("-" ^ 70)

try
    effects = find_audiounits(kAudioUnitType_Effect)

    if !isempty(effects)
        au = load_audiounit(effects[1].type, effects[1].subtype)
        initialize_audiounit(au)

        if can_bypass(au)
            println(au.name, " supports bypass mode")

            # Enable bypass
            if set_bypass(au, true)
                println("  Bypass enabled")
            end

            # Disable bypass
            if set_bypass(au, false)
                println("  Bypass disabled")
            end
        else
            println(au.name, " does not support bypass mode")
        end

        uninitialize_audiounit(au)
        dispose_audiounit(au)
    end

catch e
    println("Error: ", e)
end

println()
println("=" ^ 70)
println("Advanced examples complete!")
