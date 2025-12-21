# Display demonstration for AudioUnits.jl
# This example shows how AudioUnits and parameters are displayed

using AudioUnits

println("AudioUnits.jl - Display Demonstration")
println("=" ^ 70)
println()

# Find an effect to demonstrate with
effects = find_audiounits(kAudioUnitType_Effect)

if isempty(effects)
    println("No effect units found on this system")
    exit(1)
end

println("Loading: ", effects[1].name)
println()

# Load an AudioUnit
au = load_audiounit(effects[1].type, effects[1].subtype)

println("1. Compact display (single line):")
println("-" ^ 70)
show(stdout, au)
println()
println()

println("2. Multi-line plain text display (terminal):")
println("-" ^ 70)
show(stdout, MIME("text/plain"), au)
println()
println()

# Initialize to get more information
initialize_audiounit(au)

println("3. After initialization:")
println("-" ^ 70)
show(stdout, MIME("text/plain"), au)
println()
println()

# Get parameters
params = get_parameters(au)

if !isempty(params)
    println("4. Displaying a parameter:")
    println("-" ^ 70)
    param = params[1]

    println("Compact display:")
    show(stdout, param)
    println()
    println()

    println("Multi-line plain text display:")
    show(stdout, MIME("text/plain"), param)
    println()
    println()

    println("5. Displaying parameter info:")
    println("-" ^ 70)
    info = param.info

    println("Compact display:")
    show(stdout, info)
    println()
    println()

    println("Multi-line plain text display:")
    show(stdout, MIME("text/plain"), info)
    println()
    println()
end

println("6. HTML display (for Jupyter notebooks):")
println("-" ^ 70)
println("To see HTML rendering, use this in a Jupyter notebook:")
println()
println("    using AudioUnits")
println("    au = load_audiounit(\"AULowpass\")")
println("    initialize_audiounit(au)")
println("    display(au)  # Will automatically use HTML rendering")
println()
println("You can also explicitly request HTML output:")
println("    show(stdout, MIME(\"text/html\"), au)")
println()

# Show a sample of the HTML output
println("Sample HTML output (first 500 characters):")
html_io = IOBuffer()
show(html_io, MIME("text/html"), au)
html_str = String(take!(html_io))
println(first(html_str, min(500, length(html_str))))
println("...")
println()

# Clean up
uninitialize_audiounit(au)
dispose_audiounit(au)

println("=" ^ 70)
println("Display demonstration complete!")
println()
println("Tips:")
println("  - Use display(au) in REPL for automatic format selection")
println("  - In Jupyter notebooks, objects are displayed with HTML automatically")
println("  - Use show(io, MIME(\"text/plain\"), obj) for plain text")
println("  - Use show(io, MIME(\"text/html\"), obj) for HTML")
