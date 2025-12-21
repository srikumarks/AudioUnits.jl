# Basic usage examples for AudioUnits.jl

using AudioUnits

println("AudioUnits.jl - Basic Usage Examples")
println("=" ^ 70)
println()

# Example 1: List all available AudioUnits
println("Example 1: Listing all available AudioUnits")
println("-" ^ 70)
all_units = find_audiounits()
println("Found ", length(all_units), " AudioUnit(s) on this system")
println()

# Show first few
for i in 1:min(5, length(all_units))
    unit = all_units[i]
    println("  ", i, ". ", unit.name, " (", unit.manufacturer, ")")
    println("     Type: ", unit.type)
end
if length(all_units) > 5
    println("  ... and ", length(all_units) - 5, " more")
end
println()

# Example 2: List only effect units
println("Example 2: Finding effect processors")
println("-" ^ 70)
effects = find_audiounits(kAudioUnitType_Effect)
println("Found ", length(effects), " effect processor(s)")
for effect in effects[1:min(3, length(effects))]
    println("  - ", effect.name)
end
println()

# Example 3: List music devices (instruments)
println("Example 3: Finding music devices (instruments)")
println("-" ^ 70)
instruments = find_audiounits(kAudioUnitType_MusicDevice)
println("Found ", length(instruments), " music device(s)")
for instrument in instruments[1:min(3, length(instruments))]
    println("  - ", instrument.name)
end
println()

# Example 4: Load and inspect a specific AudioUnit
# Note: This example uses a common macOS AudioUnit. Adjust the name if needed.
println("Example 4: Loading and inspecting an AudioUnit")
println("-" ^ 70)

# Try to load a common effect
au_name = "AULowpass"  # Low-pass filter, commonly available on macOS

try
    au = load_audiounit(au_name)
    println("Successfully loaded: ", au.name)
    println()

    # Get basic info
    info = get_info(au)
    println("Information:")
    println("  Manufacturer: ", info.manufacturer)
    println("  Version: ", join(info.version, "."))
    println("  Supports effects: ", info.supports_effects)
    println("  Supports MIDI: ", info.supports_midi)
    println("  Parameter count: ", info.parameter_count)
    println()

    # Get parameters
    println("Parameters:")
    params = get_parameters(au)
    for param in params
        println("  ", param.info.name)
        println("    Range: ", param.info.min_value, " to ", param.info.max_value, " ", param.info.unit_name)
        println("    Default: ", param.info.default_value)
    end
    println()

    # Clean up
    dispose_audiounit(au)
    println("AudioUnit disposed successfully")

catch e
    println("Could not load AudioUnit '", au_name, "': ", e)
    println("Try changing 'au_name' to an AudioUnit available on your system")
end

println()
println("=" ^ 70)
println("Examples complete!")
