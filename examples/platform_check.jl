# Cross-Platform Import Example
#
# This example demonstrates that AudioUnits.jl can be imported on any platform,
# with runtime checking for platform support.

using AudioUnits

println("AudioUnits.jl - Platform Support Check")
println("=" ^ 70)
println()

# Check if AudioUnits are supported on this platform
if issupported()
    println("✓ AudioUnits ARE supported on this platform (macOS)")
    println()

    # Safe to use AudioUnits functionality
    println("Querying available AudioUnits...")
    units = findaudiounits()
    println("Found ", length(units), " AudioUnits on this system")

    if !isempty(units)
        println()
        println("First few AudioUnits:")
        for (i, unit) in enumerate(units[1:min(5, length(units))])
            println("  ", i, ". ", unit.name, " (", unit.manufacturer, ")")
        end
    end
else
    println("✗ AudioUnits are NOT supported on this platform")
    println()
    println("AudioUnits are only available on macOS (Apple platforms).")
    println("Current platform: ", Sys.KERNEL)
    println()
    println("The package can be imported successfully, but AudioUnit")
    println("functionality will not work on this platform.")
end

println()
println("=" ^ 70)
println()
println("Usage pattern for cross-platform code:")
println()
println("```julia")
println("using AudioUnits")
println()
println("if issupported()")
println("    # Use AudioUnits functionality")
println("    au = load(\"AULowpass\")")
println("    # ...")
println("else")
println("    # Use alternative audio processing")
println("    println(\"Using fallback audio processing\")")
println("end")
println("```")
