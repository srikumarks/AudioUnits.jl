# AudioUnit documentation and information retrieval

"""
    get_documentation(au::AudioUnit) -> String

Get basic documentation and information about an AudioUnit.

Returns a formatted string with:
- AudioUnit name and manufacturer
- Type and version information
- Supported capabilities
- Parameter list with ranges

# Examples
```julia
au = load_audiounit("AULowpass")
println(get_documentation(au))
```
"""
function get_documentation(au::AudioUnit)
    io = IOBuffer()

    println(io, "=" ^ 70)
    println(io, "AudioUnit: ", au.name)
    println(io, "=" ^ 70)
    println(io)

    # Basic information
    println(io, "Manufacturer: ", au.manufacturer)
    println(io, "Type: ", au.au_type)
    println(io, "Subtype: ", fourcc_to_string(au.subtype), " (0x", string(au.subtype, base=16), ")")

    # Version number (format: 0xMMMMmmBB where M=major, m=minor, B=bugfix)
    major = (au.version >> 16) & 0xFFFF
    minor = (au.version >> 8) & 0xFF
    bugfix = au.version & 0xFF
    println(io, "Version: ", major, ".", minor, ".", bugfix)
    println(io)

    # Capabilities
    println(io, "Capabilities:")
    println(io, "  - Effects Processing: ", supports_effects(au) ? "Yes" : "No")
    println(io, "  - MIDI Input: ", supports_midi(au) ? "Yes" : "No")
    println(io, "  - Bypass Support: ", can_bypass(au) ? "Yes" : "No")
    println(io)

    # Channel configurations
    println(io, "Supported Channel Configurations:")
    configs = get_channel_capabilities(au)
    for config in configs
        in_ch = config.input_channels
        out_ch = config.output_channels

        # Negative values indicate flexible channel counts
        in_str = in_ch < 0 ? "any" : string(in_ch)
        out_str = out_ch < 0 ? "any" : string(out_ch)

        println(io, "  - Input: ", in_str, " channels, Output: ", out_str, " channels")
    end
    println(io)

    # Latency and tail (if initialized)
    if au.initialized
        latency = get_latency(au)
        tail = get_tail_time(au)

        if latency > 0
            println(io, "Latency: ", round(latency * 1000, digits=2), " ms")
        end
        if tail > 0
            println(io, "Tail Time: ", round(tail, digits=3), " seconds")
        end
        if latency > 0 || tail > 0
            println(io)
        end
    end

    # Parameters
    params = get_parameters(au)

    if !isempty(params)
        println(io, "Parameters (", length(params), " total):")
        println(io, "-" ^ 70)

        for param in params
            info = param.info
            println(io)
            println(io, "  Name: ", info.name)
            println(io, "  ID: ", param.id)
            println(io, "  Range: ", info.min_value, " to ", info.max_value, " ", info.unit_name)
            println(io, "  Default: ", info.default_value)

            # Show current value if initialized
            if au.initialized
                try
                    current = get_parameter_value(au, param.id, scope=param.scope)
                    println(io, "  Current: ", current)
                catch
                    # Some parameters may not be readable
                end
            end
        end
    else
        println(io, "No parameters available")
    end

    println(io)
    println(io, "=" ^ 70)

    return String(take!(io))
end

"""
    get_info(au::AudioUnit) -> AudioUnitSummary

Get structured information about an AudioUnit.

Returns an `AudioUnitSummary` struct with:
- `name`: AudioUnit name
- `manufacturer`: Manufacturer name
- `type`: AudioUnitType
- `subtype`: Subtype code
- `version`: Version tuple (major, minor, bugfix)
- `supports_effects`: Boolean
- `supports_midi`: Boolean
- `can_bypass`: Boolean
- `channel_configs`: Vector of supported configurations
- `parameter_count`: Number of parameters
- `initialized`: Initialization status

# Examples
```julia
info = get_info(au)
println("AudioUnit: ", info.name, " v", join(info.version, "."))
println("Parameters: ", info.parameter_count)
```
"""
function get_info(au::AudioUnit)
    major = (au.version >> 16) & 0xFFFF
    minor = (au.version >> 8) & 0xFF
    bugfix = au.version & 0xFF

    params = get_parameters(au)

    return AudioUnitSummary(
        au.name,
        au.manufacturer,
        au.au_type,
        au.subtype,
        (major, minor, bugfix),
        supports_effects(au),
        supports_midi(au),
        can_bypass(au),
        get_channel_capabilities(au),
        length(params),
        au.initialized
    )
end

"""
    list_all_audiounits(; type::Union{AudioUnitType, Nothing} = nothing) -> String

Get a formatted list of all available AudioUnits on the system.

# Examples
```julia
# List all AudioUnits
println(list_all_audiounits())

# List only effects
println(list_all_audiounits(type=kAudioUnitType_Effect))

# List only instruments
println(list_all_audiounits(type=kAudioUnitType_MusicDevice))
```
"""
function list_all_audiounits(; type::Union{AudioUnitType, Nothing} = nothing)
    units = find_audiounits(type)

    io = IOBuffer()

    title = isnothing(type) ? "All AudioUnits" : "AudioUnits of type: $type"
    println(io, "=" ^ 70)
    println(io, title)
    println(io, "=" ^ 70)
    println(io)
    println(io, "Found ", length(units), " AudioUnit(s)")
    println(io)

    if isempty(units)
        println(io, "No AudioUnits found.")
        return String(take!(io))
    end

    # Group by type
    by_type = Dict{AudioUnitType, Vector{eltype(units)}}()
    for unit in units
        if !haskey(by_type, unit.type)
            by_type[unit.type] = []
        end
        push!(by_type[unit.type], unit)
    end

    # Print grouped by type
    for au_type in sort(collect(keys(by_type)))
        type_units = by_type[au_type]
        println(io, au_type, " (", length(type_units), "):")
        println(io, "-" ^ 70)

        for unit in sort(type_units, by = u -> u.name)
            major = (unit.version >> 16) & 0xFFFF
            minor = (unit.version >> 8) & 0xFF
            bugfix = unit.version & 0xFF

            println(io, "  ", unit.name)
            println(io, "    Manufacturer: ", unit.manufacturer)
            println(io, "    Subtype: ", fourcc_to_string(unit.subtype))
            println(io, "    Version: ", major, ".", minor, ".", bugfix)
            println(io)
        end
    end

    return String(take!(io))
end
