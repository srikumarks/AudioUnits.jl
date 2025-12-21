# AudioUnit documentation and information retrieval

"""
    documentation(au::AudioUnit) -> String

Get basic documentation and information about an AudioUnit.

Returns a formatted string with:
- AudioUnit name and manufacturer
- Type and version information
- Supported capabilities
- Parameter list with ranges

# Examples
```julia
au = load("AULowpass")
println(documentation(au))
```
"""
function documentation(au::AudioUnit)
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
    println(io, "  - Effects Processing: ", supportseffects(au) ? "Yes" : "No")
    println(io, "  - MIDI Input: ", supportsmidi(au) ? "Yes" : "No")
    println(io, "  - Bypass Support: ", canbypass(au) ? "Yes" : "No")
    println(io)

    # Channel configurations
    println(io, "Supported Channel Configurations:")
    configs = channelcapabilities(au)
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
        lat = latency(au)
        tail = tailtime(au)

        if lat > 0
            println(io, "Latency: ", round(lat * 1000, digits=2), " ms")
        end
        if tail > 0
            println(io, "Tail Time: ", round(tail, digits=3), " seconds")
        end
        if lat > 0 || tail > 0
            println(io)
        end
    end

    # Parameters
    params = parameters(au)

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
                    current = parametervalue(au, param.id, scope=param.scope)
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
    info(au::AudioUnit) -> AudioUnitSummary

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
au_info = info(au)
println("AudioUnit: ", au_info.name, " v", join(au_info.version, "."))
println("Parameters: ", au_info.parameter_count)
```
"""
function info(au::AudioUnit)
    major = (au.version >> 16) & 0xFFFF
    minor = (au.version >> 8) & 0xFF
    bugfix = au.version & 0xFF

    params = parameters(au)

    return AudioUnitSummary(
        au.name,
        au.manufacturer,
        au.au_type,
        au.subtype,
        (major, minor, bugfix),
        supportseffects(au),
        supportsmidi(au),
        canbypass(au),
        channelcapabilities(au),
        length(params),
        au.initialized
    )
end

"""
    listall(; type::Union{AudioUnitType, Nothing} = nothing) -> String

Get a formatted list of all available AudioUnits on the system.

# Examples
```julia
# List all AudioUnits
println(listall())

# List only effects
println(listall(type=kAudioUnitType_Effect))

# List only instruments
println(listall(type=kAudioUnitType_MusicDevice))
```
"""
function listall(; type::Union{AudioUnitType, Nothing} = nothing)
    units = findaudiounits(type)

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
