# Streaming Audio Processing with Small Buffers
#
# This example demonstrates processing audio in small chunks (64, 128, or 256 samples)
# which is essential for low-latency streaming applications.

using AudioUnits
using SampledSignals

println("AudioUnits.jl - Streaming with Small Buffers Example")
println("=" ^ 70)
println()

# Configuration
const BUFFER_SIZE = 128  # Small buffer for low latency
const SAMPLE_RATE = 44100
const NUM_BUFFERS = 100   # Process 100 small buffers
const DURATION = (BUFFER_SIZE * NUM_BUFFERS) / SAMPLE_RATE

println("Configuration:")
println("  Buffer size: ", BUFFER_SIZE, " samples")
println("  Sample rate: ", SAMPLE_RATE, " Hz")
println("  Total buffers: ", NUM_BUFFERS)
println("  Total duration: ", round(DURATION, digits=2), " seconds")
println()

# Load and initialize an effect
println("Loading AULowpass filter...")
au = load("AULowpass")
initialize(au)

# Set some parameters
params = parameters(au)
if !isempty(params)
    println("Setting filter parameters...")
    setparametervalue!(au, params[1].id, 0.4)  # Cutoff frequency
end

println()
println("Processing audio in small buffers...")
println("-" ^ 70)

# Generate input signal: white noise
println("Generating input signal...")
full_input = randn(Float32, 2, BUFFER_SIZE * NUM_BUFFERS)

# Process in small chunks
output_buffers = SampleBuf[]

println("Processing ", NUM_BUFFERS, " buffers of ", BUFFER_SIZE, " samples each:")
for i in 1:NUM_BUFFERS
    # Extract a small chunk
    start_idx = (i - 1) * BUFFER_SIZE + 1
    end_idx = i * BUFFER_SIZE
    chunk = view(full_input, :, start_idx:end_idx)

    # Create SampleBuf for this chunk
    input_buf = SampleBuf(collect(chunk), SAMPLE_RATE)

    # Process through AudioUnit
    output_buf = processbuffer(au, input_buf)

    # Store result
    push!(output_buffers, output_buf)

    # Progress indicator
    if i % 10 == 0
        println("  Processed ", i, "/", NUM_BUFFERS, " buffers...")
    end
end

println("Done!")
println()

# Reconstruct full output
println("Reconstructing full output signal...")
output_data = hcat([buf.data for buf in output_buffers]...)
full_output = SampleBuf(output_data, SAMPLE_RATE)

println("Input:  ", size(full_input), " samples")
println("Output: ", size(full_output), " samples")
println()

# Example 2: Streaming with different buffer sizes
println()
println("Example 2: Comparing different buffer sizes")
println("-" ^ 70)

buffer_sizes = [64, 128, 256, 512]

for buf_size in buffer_sizes
    println("Testing buffer size: ", buf_size, " samples")

    # Generate test input
    test_input = SampleBuf(randn(Float32, 2, buf_size), SAMPLE_RATE)

    # Process
    test_output = processbuffer(au, test_input)

    println("  Processed successfully: ", size(test_output, 2), " samples out")
end

println()

# Clean up
uninitialize(au)
dispose(au)

println()
println("=" ^ 70)
println("Streaming example complete!")
println()
println("Key points:")
println("  - processbuffer() works with any buffer size")
println("  - Small buffers (64-128) are ideal for low-latency streaming")
println("  - AudioUnit state is maintained between calls")
println("  - Perfect for real-time processing pipelines")
println()
println("Use cases:")
println("  - Live audio input processing")
println("  - Network audio streaming")
println("  - Real-time effect chains")
println("  - Low-latency music applications")

# Example 5: Zero-allocation streaming with processbuffer!
println()
println("Example 5: Zero-allocation streaming with processbuffer!")
println("-" ^ 70)

# Create effect
au5 = load("AULowpass")
initialize(au5)

# Pre-allocate input and output buffers once
BUFSIZE = 128
input_buf = SampleBuf(zeros(Float32, 2, BUFSIZE), SAMPLE_RATE)
output_buf = SampleBuf(zeros(Float32, 2, BUFSIZE), SAMPLE_RATE)

println("Pre-allocated buffers: ", BUFSIZE, " samples each")
println("Processing ", NUM_BUFFERS, " buffers with zero-allocation in-place processing:")

# Process many buffers without any allocation
for i in 1:NUM_BUFFERS
    # Fill input buffer with new data
    input_buf.data .= randn(Float32, 2, BUFSIZE)
    
    # Process in-place - no allocation!
    processbuffer!(output_buf, au5, input_buf)
    
    # Progress indicator
    if i % 10 == 0
        println("  Processed ", i, "/", NUM_BUFFERS, " buffers...")
    end
end

println("Done!")
println()
println("Performance comparison:")
println("  - processbuffer():  Allocates new output buffer every call")
println("  - processbuffer!(): Reuses pre-allocated buffer (zero GC pressure)")

# Clean up
uninitialize(au5)
dispose(au5)

println()
println("=" ^ 70)
println("Streaming examples complete!")
println()
println("Key points:")
println("  - processbuffer() works with any buffer size")
println("  - Small buffers (64-128) are ideal for low-latency streaming")
println("  - AudioUnit state is maintained between calls")
println("  - processbuffer!() eliminates allocations for maximum performance")
println()
println("Use cases:")
println("  - Live audio input processing")
println("  - Network audio streaming")
println("  - Real-time effect chains")
println("  - Low-latency music applications")
println("  - High-performance batch processing")
