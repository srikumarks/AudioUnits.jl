# Display methods for AudioUnits and parameters

# ==============================================================================
# AudioUnitParameterInfo display methods
# ==============================================================================

"""
    Base.show(io::IO, info::AudioUnitParameterInfo)

Compact single-line display of parameter info.
"""
function Base.show(io::IO, info::AudioUnitParameterInfo)
    print(io, "AudioUnitParameterInfo(\"", info.name, "\", ",
          info.min_value, ":", info.max_value, " ", info.unit_name, ")")
end

"""
    Base.show(io::IO, ::MIME"text/plain", info::AudioUnitParameterInfo)

Multi-line plain text display of parameter info for terminal.
"""
function Base.show(io::IO, ::MIME"text/plain", info::AudioUnitParameterInfo)
    println(io, "AudioUnitParameterInfo:")
    println(io, "  Name: ", info.name)
    println(io, "  Unit: ", info.unit_name)
    println(io, "  Range: [", info.min_value, ", ", info.max_value, "]")
    print(io,   "  Default: ", info.default_value)
end

"""
    Base.show(io::IO, ::MIME"text/html", info::AudioUnitParameterInfo)

HTML display of parameter info for Jupyter notebooks.
"""
function Base.show(io::IO, ::MIME"text/html", info::AudioUnitParameterInfo)
    print(io, """
    <div style="border: 1px solid #ddd; border-radius: 4px; padding: 10px; margin: 5px 0; background-color: #f9f9f9;">
        <h4 style="margin: 0 0 8px 0; color: #333;">AudioUnitParameterInfo</h4>
        <table style="width: 100%; border-collapse: collapse;">
            <tr><td style="padding: 4px; font-weight: bold; width: 30%;">Name:</td><td style="padding: 4px;">$(info.name)</td></tr>
            <tr><td style="padding: 4px; font-weight: bold;">Unit:</td><td style="padding: 4px;">$(info.unit_name)</td></tr>
            <tr><td style="padding: 4px; font-weight: bold;">Range:</td><td style="padding: 4px;">[$(info.min_value), $(info.max_value)]</td></tr>
            <tr><td style="padding: 4px; font-weight: bold;">Default:</td><td style="padding: 4px;">$(info.default_value)</td></tr>
        </table>
    </div>
    """)
end

# ==============================================================================
# AudioUnitParameter display methods
# ==============================================================================

"""
    Base.show(io::IO, param::AudioUnitParameter)

Compact single-line display of parameter.
"""
function Base.show(io::IO, param::AudioUnitParameter)
    print(io, "AudioUnitParameter(", param.id, ", \"", param.info.name, "\")")
end

"""
    Base.show(io::IO, ::MIME"text/plain", param::AudioUnitParameter)

Multi-line plain text display of parameter for terminal.
"""
function Base.show(io::IO, ::MIME"text/plain", param::AudioUnitParameter)
    println(io, "AudioUnitParameter:")
    println(io, "  ID: ", param.id)
    println(io, "  Scope: ", scope_to_string(param.scope))
    println(io, "  Element: ", param.element)
    println(io, "  Name: ", param.info.name)
    println(io, "  Unit: ", param.info.unit_name)
    println(io, "  Range: [", param.info.min_value, ", ", param.info.max_value, "]")
    print(io,   "  Default: ", param.info.default_value)
end

"""
    Base.show(io::IO, ::MIME"text/html", param::AudioUnitParameter)

HTML display of parameter for Jupyter notebooks.
"""
function Base.show(io::IO, ::MIME"text/html", param::AudioUnitParameter)
    scope_name = scope_to_string(param.scope)

    print(io, """
    <div style="border: 2px solid #4CAF50; border-radius: 6px; padding: 12px; margin: 8px 0; background-color: #f1f8f4;">
        <h4 style="margin: 0 0 10px 0; color: #2E7D32;">AudioUnitParameter</h4>
        <table style="width: 100%; border-collapse: collapse;">
            <tr><td style="padding: 5px; font-weight: bold; width: 30%;">ID:</td><td style="padding: 5px;">$(param.id)</td></tr>
            <tr><td style="padding: 5px; font-weight: bold;">Scope:</td><td style="padding: 5px;">$(scope_name)</td></tr>
            <tr><td style="padding: 5px; font-weight: bold;">Element:</td><td style="padding: 5px;">$(param.element)</td></tr>
            <tr><td style="padding: 5px; font-weight: bold;">Name:</td><td style="padding: 5px;"><strong>$(param.info.name)</strong></td></tr>
            <tr><td style="padding: 5px; font-weight: bold;">Unit:</td><td style="padding: 5px;">$(param.info.unit_name)</td></tr>
            <tr><td style="padding: 5px; font-weight: bold;">Range:</td><td style="padding: 5px;">[$(param.info.min_value), $(param.info.max_value)]</td></tr>
            <tr><td style="padding: 5px; font-weight: bold;">Default:</td><td style="padding: 5px;">$(param.info.default_value)</td></tr>
        </table>
    </div>
    """)
end

# ==============================================================================
# AudioUnit display methods
# ==============================================================================

"""
    Base.show(io::IO, au::AudioUnit)

Compact single-line display of AudioUnit.
"""
function Base.show(io::IO, au::AudioUnit)
    status = au.initialized ? "initialized" : "uninitialized"
    print(io, "AudioUnit(\"", au.name, "\", ", au.au_type, ", ", status, ")")
end

"""
    Base.show(io::IO, ::MIME"text/plain", au::AudioUnit)

Multi-line plain text display of AudioUnit for terminal.
"""
function Base.show(io::IO, ::MIME"text/plain", au::AudioUnit)
    println(io, "╭─────────────────────────────────────────────────────────────────╮")
    println(io, "│ AudioUnit: ", au.name, " "^max(0, 44 - length(au.name)), "│")
    println(io, "╰─────────────────────────────────────────────────────────────────╯")
    println(io)

    # Basic Information
    println(io, "Basic Information:")
    println(io, "  Manufacturer: ", au.manufacturer)
    println(io, "  Type: ", au.au_type)
    println(io, "  Subtype: ", fourcc_to_string(au.subtype), " (0x", string(au.subtype, base=16), ")")

    major = (au.version >> 16) & 0xFFFF
    minor = (au.version >> 8) & 0xFF
    bugfix = au.version & 0xFF
    println(io, "  Version: ", major, ".", minor, ".", bugfix)
    println(io, "  Status: ", au.initialized ? "Initialized" : "Uninitialized")
    println(io)

    # Capabilities
    println(io, "Capabilities:")
    println(io, "  Effects Processing: ", supportseffects(au) ? "✓" : "✗")
    println(io, "  MIDI Input: ", supportsmidi(au) ? "✓" : "✗")
    println(io, "  Bypass Support: ", canbypass(au) ? "✓" : "✗")
    println(io)

    # Channel Configurations
    println(io, "Channel Configurations:")
    configs = channelcapabilities(au)
    for (i, config) in enumerate(configs)
        in_ch = config.input_channels < 0 ? "any" : string(config.input_channels)
        out_ch = config.output_channels < 0 ? "any" : string(config.output_channels)
        println(io, "  [", i, "] Input: ", in_ch, " ch, Output: ", out_ch, " ch")
    end
    println(io)

    # Performance characteristics (if initialized)
    if au.initialized
        latency_val = latency(au)
        tail = tailtime(au)

        if latency_val > 0 || tail > 0
            println(io, "Performance:")
            if latency_val > 0
                println(io, "  Latency: ", round(latency_val * 1000, digits=2), " ms")
            end
            if tail > 0
                println(io, "  Tail Time: ", round(tail, digits=3), " s")
            end
            println(io)
        end
    end

    # Parameters summary
    params = parameters(au)
    print(io, "Parameters: ", length(params), " total")

    if !isempty(params) && get(io, :limit, true)
        println(io, " (showing first 3)")
        for param in params[1:min(3, length(params))]
            println(io, "  • ", param.info.name, ": ",
                   param.info.min_value, " to ", param.info.max_value, " ", param.info.unit_name)
        end
        if length(params) > 3
            print(io, "  ... and ", length(params) - 3, " more")
        end
    end
end

"""
    Base.show(io::IO, ::MIME"text/html", au::AudioUnit)

HTML display of AudioUnit for Jupyter notebooks.
"""
function Base.show(io::IO, ::MIME"text/html", au::AudioUnit)
    major = (au.version >> 16) & 0xFFFF
    minor = (au.version >> 8) & 0xFF
    bugfix = au.version & 0xFF
    version_str = "$major.$minor.$bugfix"

    status_color = au.initialized ? "#4CAF50" : "#FF9800"
    status_text = au.initialized ? "Initialized" : "Uninitialized"

    # Capabilities
    effects_icon = supportseffects(au) ? "✓" : "✗"
    midi_icon = supportsmidi(au) ? "✓" : "✗"
    bypass_icon = canbypass(au) ? "✓" : "✗"

    effects_color = supportseffects(au) ? "#4CAF50" : "#999"
    midi_color = supportsmidi(au) ? "#4CAF50" : "#999"
    bypass_color = canbypass(au) ? "#4CAF50" : "#999"

    print(io, """
    <div style="border: 3px solid #2196F3; border-radius: 8px; padding: 16px; margin: 10px 0; background: linear-gradient(to bottom, #f5f5f5, #ffffff);">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; padding-bottom: 8px; border-bottom: 2px solid #2196F3;">
            <h3 style="margin: 0; color: #1976D2;">🎵 AudioUnit: $(au.name)</h3>
            <span style="background-color: $(status_color); color: white; padding: 4px 12px; border-radius: 12px; font-size: 0.9em;">$(status_text)</span>
        </div>

        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px;">
            <div>
                <h4 style="margin: 8px 0 4px 0; color: #555;">Basic Information</h4>
                <table style="width: 100%; border-collapse: collapse; font-size: 0.95em;">
                    <tr><td style="padding: 4px; font-weight: bold;">Manufacturer:</td><td style="padding: 4px;">$(au.manufacturer)</td></tr>
                    <tr><td style="padding: 4px; font-weight: bold;">Type:</td><td style="padding: 4px;">$(au.au_type)</td></tr>
                    <tr><td style="padding: 4px; font-weight: bold;">Subtype:</td><td style="padding: 4px;">$(fourcc_to_string(au.subtype))</td></tr>
                    <tr><td style="padding: 4px; font-weight: bold;">Version:</td><td style="padding: 4px;">$(version_str)</td></tr>
                </table>
            </div>

            <div>
                <h4 style="margin: 8px 0 4px 0; color: #555;">Capabilities</h4>
                <table style="width: 100%; border-collapse: collapse; font-size: 0.95em;">
                    <tr><td style="padding: 4px; font-weight: bold;">Effects Processing:</td><td style="padding: 4px; color: $(effects_color); font-size: 1.2em;">$(effects_icon)</td></tr>
                    <tr><td style="padding: 4px; font-weight: bold;">MIDI Input:</td><td style="padding: 4px; color: $(midi_color); font-size: 1.2em;">$(midi_icon)</td></tr>
                    <tr><td style="padding: 4px; font-weight: bold;">Bypass Support:</td><td style="padding: 4px; color: $(bypass_color); font-size: 1.2em;">$(bypass_icon)</td></tr>
                </table>
            </div>
        </div>
    """)

    # Channel configurations
    configs = channelcapabilities(au)
    print(io, """
        <div style="margin-top: 12px;">
            <h4 style="margin: 8px 0 4px 0; color: #555;">Channel Configurations</h4>
            <div style="display: flex; flex-wrap: wrap; gap: 8px;">
    """)

    for config in configs
        in_ch = config.input_channels < 0 ? "any" : string(config.input_channels)
        out_ch = config.output_channels < 0 ? "any" : string(config.output_channels)
        print(io, """
                <div style="background-color: #E3F2FD; border: 1px solid #2196F3; border-radius: 4px; padding: 6px 10px; font-size: 0.9em;">
                    <strong>In:</strong> $(in_ch) ch → <strong>Out:</strong> $(out_ch) ch
                </div>
        """)
    end

    println(io, """
            </div>
        </div>
    """)

    # Performance info (if initialized)
    if au.initialized
        latency_val = latency(au)
        tail = tailtime(au)

        if latency_val > 0 || tail > 0
            print(io, """
                <div style="margin-top: 12px;">
                    <h4 style="margin: 8px 0 4px 0; color: #555;">Performance</h4>
                    <table style="width: 100%; border-collapse: collapse; font-size: 0.95em;">
            """)

            if latency_val > 0
                latency_ms = round(latency_val * 1000, digits=2)
                print(io, """
                        <tr><td style="padding: 4px; font-weight: bold;">Latency:</td><td style="padding: 4px;">$(latency_ms) ms</td></tr>
                """)
            end

            if tail > 0
                tail_s = round(tail, digits=3)
                print(io, """
                        <tr><td style="padding: 4px; font-weight: bold;">Tail Time:</td><td style="padding: 4px;">$(tail_s) s</td></tr>
                """)
            end

            println(io, """
                    </table>
                </div>
            """)
        end
    end

    # Parameters
    params = parameters(au)
    print(io, """
        <div style="margin-top: 12px;">
            <h4 style="margin: 8px 0 4px 0; color: #555;">Parameters ($(length(params)) total)</h4>
    """)

    if !isempty(params)
        print(io, """
            <div style="max-height: 200px; overflow-y: auto; border: 1px solid #ddd; border-radius: 4px; padding: 8px; background-color: #fafafa;">
                <table style="width: 100%; border-collapse: collapse; font-size: 0.9em;">
                    <thead style="position: sticky; top: 0; background-color: #E3F2FD;">
                        <tr>
                            <th style="text-align: left; padding: 6px; border-bottom: 2px solid #2196F3;">Name</th>
                            <th style="text-align: left; padding: 6px; border-bottom: 2px solid #2196F3;">Range</th>
                            <th style="text-align: left; padding: 6px; border-bottom: 2px solid #2196F3;">Default</th>
                            <th style="text-align: left; padding: 6px; border-bottom: 2px solid #2196F3;">Unit</th>
                        </tr>
                    </thead>
                    <tbody>
        """)

        for param in params
            print(io, """
                        <tr style="border-bottom: 1px solid #eee;">
                            <td style="padding: 6px;">$(param.info.name)</td>
                            <td style="padding: 6px;">[$(param.info.min_value), $(param.info.max_value)]</td>
                            <td style="padding: 6px;">$(param.info.default_value)</td>
                            <td style="padding: 6px;">$(param.info.unit_name)</td>
                        </tr>
            """)
        end

        print(io, """
                    </tbody>
                </table>
            </div>
        """)
    else
        print(io, """
            <p style="color: #999; font-style: italic;">No parameters available</p>
        """)
    end

    print(io, """
        </div>
    </div>
    """)
end

# ==============================================================================
# Helper functions
# ==============================================================================

function scope_to_string(scope::UInt32)::String
    scopes = Dict(
        kAudioUnitScope_Global => "Global",
        kAudioUnitScope_Input => "Input",
        kAudioUnitScope_Output => "Output",
        kAudioUnitScope_Group => "Group",
        kAudioUnitScope_Part => "Part",
        kAudioUnitScope_Note => "Note",
        kAudioUnitScope_Layer => "Layer",
        kAudioUnitScope_LayerItem => "LayerItem"
    )
    return get(scopes, scope, "Unknown")
end
