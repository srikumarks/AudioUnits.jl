# Offline Audio Processing with AudioProcessor
#
# This example demonstrates the recommended way to process audio offline
# using the AudioProcessor API. Unlike the deprecated processbuffer functions,
# AudioProcessor is safe, reusable, and efficient.

using AudioUnits, SampledSignals
using Statistics: mean

println("AudioUnits.jl - Offline Audio Processing Example")
println("=" ^ 70)
println()

# ============================================================================
# Example 1: Simple Single-Pass Processing
# ============================================================================

println("Example 1: Simple Single-Pass Processing")
println("-" ^ 70)
println()

# Load and initialize the effect
au = load("Apple: AULowpass")
initialize(au)

# Create processor with appropriate settings
sr = 44100.0
max_channels = 2
max_frames = 1024
processor = AudioProcessor(au, max_channels=max_channels, max_frames=max_frames, sample_rate=sr)

# Create input audio (1 second of noise)
println("Creating 1 second of stereo noise...")
input = SampleBuf(randn(Float32, 2, sr) .* 0.1, sr)
println("  Input size: $(size(input.data)) channels × samples")
println("  Input RMS: $(round(sqrt(mean(input.data.^2)), digits=4))")

# Process the audio
println("Processing through lowpass filter...")
output = process(processor, input)
println("  Output size: $(size(output.data)) channels × samples")
println("  Output RMS: $(round(sqrt(mean(output.data.^2)), digits=4))")

# Clean up
dispose(processor)
uninitialize(au)
dispose(au)

println()
println()

# ============================================================================
# Example 2: Streaming with Zero Allocation
# ============================================================================

println("Example 2: Streaming with Zero Allocation (Perfect for Real-Time)")
println("-" ^ 70)
println()

# Load effect
au = load("Apple: AULowpass")
initialize(au)

# Create processor optimized for streaming
chunk_size = 256  # Small buffer for low latency
processor = AudioProcessor(au, max_channels=2, max_frames=chunk_size, sample_rate=44100.0)

# Pre-allocate input and output buffers (no allocation during processing!)
input_buf = SampleBuf(zeros(Float32, 2, chunk_size), 44100.0)
output_buf = SampleBuf(zeros(Float32, 2, chunk_size), 44100.0)

println("Processing 100 chunks of $chunk_size samples (zero allocation)...")
println()

total_samples_processed = 0
for i in 1:100
    # Generate or load new audio data
    input_buf.data .= randn(Float32, 2, chunk_size) .* 0.1

    # Process in-place (no allocation!)
    process!(processor, input_buf, output_buf)

    total_samples_processed += chunk_size

    if i % 20 == 0
        rms = sqrt(mean(output_buf.data.^2))
        println("  Chunk $i: processed $total_samples_processed samples, output RMS = $(round(rms, digits=4))")
    end
end

dispose(processor)
uninitialize(au)
dispose(au)

println()
println("Successfully processed $(total_samples_processed ÷ 44100).$((total_samples_processed % 44100) ÷ 441) seconds of audio!")
println()
println()

# ============================================================================
# Example 3: Processing Different Buffer Sizes
# ============================================================================

println("Example 3: Processing Different Buffer Sizes (All Within Max)")
println("-" ^ 70)
println()

au = load("Apple: AULowpass")
initialize(au)

# Create processor that supports up to 4096 samples
max_frames = 4096
processor = AudioProcessor(au, max_channels=2, max_frames=max_frames, sample_rate=44100.0)

buffer_sizes = [256, 512, 1024, 2048, 4096]

println("Processing various buffer sizes with the same processor:")
for size in buffer_sizes
    input = SampleBuf(randn(Float32, 2, size) .* 0.1, 44100.0)
    output = process(processor, input)
    rms = sqrt(mean(output.data.^2))
    println("  $size samples: ✓ (output RMS = $(round(rms, digits=4)))")
end

dispose(processor)
uninitialize(au)
dispose(au)

println()
println()

# ============================================================================
# Example 4: Multiple Effects Chain
# ============================================================================

println("Example 4: Processing Through Multiple Effects in Sequence")
println("-" ^ 70)
println()

# Load two effects
lowpass = load("Apple: AULowpass")
initialize(lowpass)

# Create input
sr = 44100.0
input = SampleBuf(randn(Float32, 2, sr) .* 0.1, sr)

println("Processing through effect chain:")
println("  Input → Lowpass → Output")
println()

# Create processors
processor1 = AudioProcessor(lowpass, max_channels=2, max_frames=2048, sample_rate=sr)

# Process
println("Applying lowpass filter...")
intermediate = process(processor1, input)
input_rms = sqrt(mean(input.data.^2))
output_rms = sqrt(mean(intermediate.data.^2))
println("  Input RMS: $(round(input_rms, digits=4))")
println("  Output RMS: $(round(output_rms, digits=4))")

# Clean up
dispose(processor1)
uninitialize(lowpass)
dispose(lowpass)

println()
println()

# ============================================================================
# Example 5: Error Handling
# ============================================================================

println("Example 5: Error Handling and Validation")
println("-" ^ 70)
println()

au = load("Apple: AULowpass")
initialize(au)

processor = AudioProcessor(au, max_channels=2, max_frames=1024, sample_rate=44100.0)

println("Testing validation and error handling:")
println()

# Test 1: Valid processing
try
    input = SampleBuf(randn(Float32, 2, 512), 44100.0)
    output = process(processor, input)
    println("✓ Valid 512-sample buffer: Success")
catch e
    println("✗ Valid 512-sample buffer: $(e.msg)")
end

# Test 2: Buffer too large
try
    input = SampleBuf(randn(Float32, 2, 2048), 44100.0)
    output = process(processor, input)
    println("✗ Buffer too large (2048): Should have failed!")
catch e
    println("✓ Buffer too large (2048): Correctly rejected")
end

# Test 3: Too many channels
try
    input = SampleBuf(randn(Float32, 4, 512), 44100.0)
    output = process(processor, input)
    println("✗ 4 channels: Should have failed!")
catch e
    println("✓ 4 channels: Correctly rejected")
end

# Test 4: Sample rate mismatch
try
    input = SampleBuf(randn(Float32, 2, 512), 48000.0)
    output = process(processor, input)
    println("✗ Sample rate mismatch: Should have failed!")
catch e
    println("✓ Sample rate mismatch: Correctly rejected")
end

dispose(processor)
uninitialize(au)
dispose(au)

println()
println()

# ============================================================================
# Summary
# ============================================================================

println("=" ^ 70)
println("Offline Processing Summary")
println("=" ^ 70)
println()
println("Key advantages of AudioProcessor:")
println("  • Safe: Persistent buffers, no dangling pointers")
println("  • Efficient: Reusable buffers, zero allocation after creation")
println("  • Simple: Easy to use and understand")
println("  • Reliable: Proper callback lifecycle management")
println()
println("Common patterns:")
println()
println("1. Single processing:")
println("   processor = AudioProcessor(au)")
println("   output = process(processor, input)")
println("   dispose(processor)")
println()
println("2. Streaming (zero allocation):")
println("   processor = AudioProcessor(au, max_frames=256)")
println("   input = SampleBuf(zeros(Float32, 2, 256), sr)")
println("   output = SampleBuf(zeros(Float32, 2, 256), sr)")
println("   for chunk in stream")
println("       input.data .= chunk")
println("       process!(processor, input, output)")
println("   end")
println("   dispose(processor)")
println()
println("3. Multiple buffer sizes:")
println("   processor = AudioProcessor(au, max_frames=4096)")
println("   # Can process any size up to 4096")
println("   output1 = process(processor, 512-sample input)")
println("   output2 = process(processor, 2048-sample input)")
println()
println("=" ^ 70)
println()
