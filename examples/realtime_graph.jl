# Realtime Graph Example
#
# This example demonstrates using AudioGraph in realtime mode where the graph
# automatically processes audio and outputs to hardware.

using AudioUnits

println("AudioUnits.jl - Realtime Graph Example")
println("=" ^ 70)
println()

# Example 1: Simple instrument output
println("Example 1: DLSMusicDevice with realtime output")
println("-" ^ 70)

# Create graph
graph = AudioGraph()

# Load a music device (instrument)
println("Loading DLSMusicDevice...")
au = load("DLSMusicDevice")

# Add nodes to graph
println("Adding nodes to graph...")
music_node = addnode!(graph, au)
output_node = addoutputnode!(graph)

# Connect music device to output
println("Connecting nodes...")
connect!(graph, music_node, output_node)

# Initialize the graph
println("Initializing graph...")
initializegraph!(graph)

# Initialize the AudioUnit for MIDI
initialize(au)

# Start realtime processing
println("Starting realtime audio...")
startgraph!(graph)

println()
println("Playing notes in realtime - you should hear audio!")
println()

# Play a melody
notes = [60, 62, 64, 65, 67, 69, 71, 72]  # C major scale
note_names = ["C", "D", "E", "F", "G", "A", "B", "C'"]

for (note, name) in zip(notes, note_names)
    println("  Playing ", name, " (", note, ")")
    noteon(au, note, 100)
    sleep(0.4)
    noteoff(au, note)
    sleep(0.1)
end

println()
println("Playing a chord...")
noteon(au, 60, 100)  # C
noteon(au, 64, 100)  # E
noteon(au, 67, 100)  # G
sleep(2.0)
noteoff(au, 60)
noteoff(au, 64)
noteoff(au, 67)

sleep(0.5)

# Stop the graph
println()
println("Stopping realtime audio...")
stopgraph!(graph)

# Clean up
uninitialize(au)
disposegraph!(graph)

println("Done!")
println()

# Example 2: Effect chain in realtime
println("Example 2: Multiple effects in realtime")
println("-" ^ 70)

println("Setting up effect chain...")

# Create new graph
graph2 = AudioGraph()

# In a real application, you would:
# 1. Add an input node (microphone/line input)
# 2. Add effect nodes
# 3. Add output node
# 4. Connect them in series
# 5. Start the graph

# For this example, we'll just demonstrate the structure
println("Note: For effect processing in realtime, you would:")
println("  1. Add an input device node")
println("  2. Add effect AudioUnits (lowpass, reverb, etc.)")
println("  3. Add output node")
println("  4. Connect input → effects → output")
println("  5. Start the graph")
println()
println("The graph then automatically processes live audio through the chain!")

disposegraph!(graph2)

println()
println("=" ^ 70)
println("Realtime examples complete!")
println()
println("Key points:")
println("  - AudioGraph handles all the realtime audio pulling")
println("  - You just need to connect nodes and start the graph")
println("  - Perfect for live performance, recording, or monitoring")
println("  - Audio runs continuously until stopgraph! is called")
