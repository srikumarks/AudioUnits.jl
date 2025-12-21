# Driven/Offline Graph Example
#
# This example demonstrates using AudioGraph in driven mode where you provide
# input buffers and get processed output buffers synchronously.

using AudioUnits
using SampledSignals

println("AudioUnits.jl - Driven/Offline Processing Example")
println("=" ^ 70)
println()

# Example 1: Process audio through a single effect
println("Example 1: Processing through a lowpass filter")
println("-" ^ 70)

# Create test signal: 1 second of stereo noise
samplerate = 44100
duration = 1.0
nframes = Int(samplerate * duration)

println("Creating test signal: ", duration, " second of noise at ", samplerate, " Hz")
input_signal = SampleBuf(randn(Float32, 2, nframes), samplerate)

# Load and configure effect
println("Loading AULowpass filter...")
au = load("AULowpass")
initialize(au)

# Set filter parameters if available
params = parameters(au)
if !isempty(params)
    println("Setting filter parameters...")
    # Set cutoff frequency (parameter varies by AudioUnit)
    setparametervalue!(au, params[1].id, 0.3)
end

# Process the audio
println("Processing audio through filter...")
output_signal = processbuffer(au, input_signal)

println("Input:  ", size(input_signal), " samples")
println("Output: ", size(output_signal), " samples")
println("Sample rate: ", output_signal.samplerate, " Hz")

# Clean up
uninitialize(au)
dispose(au)

println("Done!")
println()

# Example 2: Process through a graph with multiple effects
println("Example 2: Processing through an effect chain using AudioGraph")
println("-" ^ 70)

# Create graph
println("Creating AudioGraph...")
graph = AudioGraph()

# Add effects to the chain
println("Loading effects...")
lowpass = load("AULowpass")
initialize(lowpass)

# Add to graph
println("Adding nodes to graph...")
lowpass_node = addnode!(graph, lowpass)

# Initialize graph
println("Initializing graph...")
initializegraph!(graph)

# Create test signal
println("Creating test signal...")
test_input = SampleBuf(randn(Float32, 2, nframes), samplerate)

# Process through graph
println("Processing through graph...")
processed = processbuffer(graph, lowpass_node, test_input)

println("Processed ", size(processed, 2), " frames")
println("Done!")

# Clean up
uninitialize(lowpass)
disposegraph!(graph)

println()

# Example 3: Batch processing multiple buffers
println("Example 3: Batch processing multiple buffers")
println("-" ^ 70)

# Create effect
au3 = load("AULowpass")
initialize(au3)

# Process multiple short buffers
num_buffers = 5
buffer_length = 4410  # 0.1 seconds each

println("Processing ", num_buffers, " buffers of ", buffer_length, " samples each...")

outputs = SampleBuf[]

for i in 1:num_buffers
    # Generate input
    input_buf = SampleBuf(randn(Float32, 2, buffer_length), samplerate)

    # Process
    output_buf = processbuffer(au3, input_buf)

    # Store
    push!(outputs, output_buf)

    println("  Buffer ", i, "/", num_buffers, " processed")
end

println("Done! Processed ", num_buffers, " buffers")

# Clean up
uninitialize(au3)
dispose(au3)

println()

# Example 4: Processing with different channel configurations
println("Example 4: Mono to stereo processing")
println("-" ^ 70)

# Create mono input
mono_input = SampleBuf(randn(Float32, 1, nframes), samplerate)
println("Created mono input: ", size(mono_input))

# Note: Most AudioUnits expect stereo, so we need to duplicate the mono channel
stereo_from_mono = SampleBuf(repeat(mono_input.data, 2, 1), samplerate)
println("Converted to stereo: ", size(stereo_from_mono))

# Process
au4 = load("AULowpass")
initialize(au4)
output_stereo = processbuffer(au4, stereo_from_mono)

println("Output: ", size(output_stereo))

uninitialize(au4)
dispose(au4)

println()
println("=" ^ 70)
println("Driven/Offline processing examples complete!")
println()
println("Key points:")
println("  - processbuffer() works synchronously")
println("  - Input must be SampleBuf{T, 2} (stereo, channels × samples)")
println("  - Perfect for batch processing, analysis, or file conversion")
println("  - You control exactly when processing happens")
println("  - Can process in chunks or all at once")
println()
println("Next steps:")
println("  - Save output using SampledSignals' save() function")
println("  - Analyze the processed audio")
println("  - Chain multiple effects together")
