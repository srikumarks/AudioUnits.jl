# AudioUnits.jl Architecture and Design Decisions

## Overview

This document explains the architectural design of AudioUnits.jl, the challenges encountered with offline audio processing, and the recommended approaches for different use cases.

## Core Components

### 1. Type System (`src/types.jl`)

Defines Julia representations of AudioUnit types and structures:
- `AudioUnit`: Core struct representing a loaded AudioUnit
- `AudioUnitParameter`: Parameter information including metadata
- `AudioGraph`: Audio Unit Graph for connecting multiple units
- `AudioUnitInfo`, `ChannelConfiguration`, `StreamFormat`: Metadata types

### 2. Core Operations (`src/core.jl`)

Handles:
- AudioUnit discovery via AudioComponentDescription
- Loading AudioUnits by name or type/subtype
- Initialization and lifecycle management
- Property querying for capabilities and format information

### 3. Audio Graph Support (`src/graph.jl`)

Provides:
- **Realtime mode**: AUGraph connected to hardware I/O with `startgraph!()` / `stopgraph!()`
- **Driven mode**: Synchronous offline processing with `processbuffer()`

### 4. New Architecture (`src/processor.jl`)

Introduces `AudioProcessor` for safer persistent buffer management:
- All buffers allocated and retained in the struct
- Module-level callback function (no closures)
- Explicit buffer lifecycle management
- GC.@preserve for callback safety

---

## The Offline Processing Challenge

### Background: How AudioUnits Process Audio

The macOS AudioUnit framework is fundamentally designed for **pull-based, realtime streaming**:

```
AudioUnit Rendering Pipeline (Realtime)
======================================

Hardware ──reads──> Render Callback ──fills──> Your Code
(realtime needs)     (whenever data needed)    (must respond quickly)
     ↓
   Timestamp
   Audio Format
   Buffer List
   Number of Frames

Your Code Returns Immediately with Audio Filled
```

In realtime mode:
1. Hardware needs audio at a specific time
2. OS calls your render callback
3. Your callback must return audio immediately
4. Hardware continues playback
5. Process repeats continuously

### The Problem with Offline Batch Processing

Offline processing is fundamentally different:

```
Offline Processing Desired API
===============================

Your Code ──provides──> AudioUnit ──processes──> Your Code
(has all audio upfront)  (filters/effects)      (gets result back)

Example: processbuffer(au, input_samples) → output_samples
```

However, AudioUnits don't work this way. They're designed for the opposite data flow:

**The Core Issue**: AudioUnits expect to *pull* audio *from* you (via callbacks), not *push* audio *into* them.

When you use `AudioUnitRender`, it:
1. Calls your render callback to get input
2. Processes the audio internally
3. Returns the result

But your callback is only called *during* the render operation.

### Why This Causes Memory Safety Issues

Previous attempts to implement offline processing (the deprecated `processbuffer` functions) had several architectural problems:

#### Problem 1: Dangling Pointers to Stack Variables

```julia
function processbuffer(au::AudioUnit, input::SampleBuf)
    # Stack-allocated local variables
    input_buffer_list = zeros(UInt8, buffer_list_size)
    output_buffer_list = zeros(UInt8, buffer_list_size)
    callback_struct = zeros(UInt8, 2 * sizeof(Ptr{Cvoid}))

    # Create callback that captures buffer_list_size from outer scope
    callback = @cfunction(render_callback, ...) do inRefCon, ...
        # This closure captures buffer_list_size
        copysize = min(UInt32(buffer_list_size), 4 + nbuffers * 16)
    end

    # Register callback with pointers to stack variables
    unsafe_store!(..., pointer(input_buffer_list))

    # Call AudioUnitRender - calls callback with stack pointers
    ccall(:AudioUnitRender, ...)

    # Function returns - stack variables go out of scope
    # But pointers may still be in use!
end
```

**The danger**: If the callback is somehow called after the function returns, it accesses deallocated memory.

#### Problem 2: Closures and @cfunction Incompatibility

Julia's `@cfunction` macro cannot create function pointers from closures (functions with captured variables) on some platforms:

```julia
# This fails: closure captures buffer_list_size
callback = @cfunction((inRefCon) -> render_callback(inRefCon, buffer_list_size), ...)
# Error: "cfunction: closures are not supported on this platform"
```

This forced the implementation to use dangerous patterns like:
```julia
copysize = min(UInt32(buffer_list_size), 4 + nbuffers * 16)
```
Trying to avoid the capture - but this is fragile and still captures implicitly.

#### Problem 3: Callback Accumulation Without Cleanup

Each call to `processbuffer` would register a *new* callback without properly removing the old one, leading to:
- Memory leaks
- Potential callbacks from previous invocations being called
- Undefined behavior

#### Problem 4: Synchronous but Unsafe

The deprecated code attempted synchronous processing (call AudioUnitRender, wait for result), but the memory safety issues made this unreliable:
- Sometimes it worked due to GC timing luck
- Sometimes it crashed
- Segmentation faults were common during testing

---

## The AudioProcessor Solution

The new `AudioProcessor` class addresses these issues:

### Design Principles

1. **Persistent Storage**: All buffers live in the struct, not on the stack
   ```julia
   mutable struct AudioProcessor
       input_buffer_list::Vector{UInt8}  # Lives as long as processor
       output_buffer_list::Vector{UInt8}
       input_data::Matrix{Float32}
       output_data::Matrix{Float32}
   end
   ```

2. **Module-Level Callback**: No closures or captured variables
   ```julia
   # NOT a closure - no captured variables
   function audio_render_callback(inRefCon::Ptr{Cvoid}, ...)::Int32
       processor_ptr = unsafe_pointer_to_objref(inRefCon)::AudioProcessor
       # Retrieve all state from processor struct
   end
   ```

3. **Proper Lifecycle**: Explicit creation and cleanup
   ```julia
   processor = AudioProcessor(au)  # Create once
   output1 = process(processor, input1)  # Reuse
   output2 = process(processor, input2)
   dispose(processor)  # Clean up callback
   ```

4. **GC Safety**: Uses `GC.@preserve` to pin processor during rendering
   ```julia
   GC.@preserve processor begin
       ccall(:AudioUnitRender, ...)
   end
   # After block, processor can only be GC'd if no other refs
   ```

### Usage Pattern

```julia
using AudioUnits, SampledSignals

au = load("Apple: AULowpass")
initialize(au)

# Create processor (persistent buffers)
processor = AudioProcessor(au, max_channels=2, max_frames=4096)

# Process audio (reuses buffers, zero allocation)
input = SampleBuf(randn(Float32, 2, 1024), 44100.0)
output = process(processor, input)

# Clean up
dispose(processor)
uninitialize(au)
dispose(au)
```

### Advantages

- ✅ No dangling pointers
- ✅ No closures, compatible with @cfunction
- ✅ Callbacks properly cleaned up
- ✅ Reusable for multiple processing calls
- ✅ Zero allocation after creation

---

## Fundamental Limitations

Despite the improved architectural design, **offline batch processing with AudioUnits has fundamental limitations**:

### Why AudioProcessor Still Struggles

Even with persistent buffers and proper memory management, the AudioUnit rendering pipeline is fundamentally designed for realtime streaming:

1. **Pull-Based Architecture**: The callback is called *during* AudioUnitRender, and the AudioUnit decides how much data it needs and when

2. **Input/Output Coupling**: Some AudioUnits have complex state machines that depend on continuous audio flow. Discrete batch processing can confuse these state machines

3. **Timing Expectations**: Some AudioUnits rely on AudioTimeStamp and other timing information that may not make sense for offline processing

4. **Plugin Design Assumptions**: Many plugins are designed with realtime assumptions (sample rates, block sizes, timing) that may not apply to batch processing

### Known Issues

- Segmentation faults can occur during AudioUnitRender in offline mode
- Some AudioUnits may not produce expected output in offline mode
- State management between discrete buffer calls is unreliable
- Performance is not optimized for offline processing

---

## Recommended Approaches

### ✅ For Realtime Audio Output (Recommended for Most Use Cases)

**Use `AudioGraph` with `startgraph!()` / `stopgraph!()`**

```julia
graph = AudioGraph()
au = load("Apple: AULowpass")
initialize(au)

output = addoutputnode!(graph)
node = addnode!(graph, au)
connect!(graph, node, output)

initializegraph!(graph)
startgraph!(graph)

# Audio is processed and sent to speakers automatically
sleep(5.0)

stopgraph!(graph)
uninitializegraph!(graph)
dispose(au)
disposegraph!(graph)
```

**Why this works**:
- Matches AudioUnit's realtime design
- Automatic buffer management
- Hardware I/O handled by the framework
- Reliable and well-tested

**Best for**:
- Playing synthesized or processed audio
- MIDI synthesis
- Real-time effect processing
- Audio monitoring

### ✅ For MIDI Synthesis (Realtime Output)

**Use `AudioGraph` with music device AudioUnits**

```julia
graph = AudioGraph()
synth = load("DLSMusicDevice")
lowpass = load("AULowpass")

synth_node = addnode!(graph, synth)
effect_node = addnode!(graph, lowpass)
output = addoutputnode!(graph)

connect!(graph, synth_node, effect_node)
connect!(graph, effect_node, output)

initializegraph!(graph)
initialize(synth)
initialize(lowpass)
startgraph!(graph)

# Play notes - you hear them in real time
noteon(synth, 0, 60, 100)
sleep(0.5)
noteoff(synth, 0, 60)

stopgraph!(graph)
```

**Best for**:
- Music synthesis from MIDI
- Interactive audio generation
- Real-time audio feedback

### ⚠️ For Offline File Processing (Limited Support)

If you need to process audio files offline, options are:

**Option 1: External Tools** (Recommended)
```bash
# Use ffmpeg or sox for audio processing
ffmpeg -i input.wav -af "lowpass=cutoff=2000" output.wav
```

**Option 2: Loopback Device** (Advanced)
- Synthesize with AudioGraph
- Record via system loopback device (like Soundflower)
- Post-process the recording

**Option 3: AudioProcessor** (Experimental)
- Works for simple effects
- May fail for complex AudioUnits
- Not suitable for production use

```julia
au = load("Apple: AULowpass")
initialize(au)

processor = AudioProcessor(au, max_channels=2, max_frames=4096)

# Try processing - may work or may segfault
try
    input = SampleBuf(randn(Float32, 2, 1024), 44100.0)
    output = process(processor, input)
    # Use output...
catch e
    println("Offline processing failed: ", e)
end

dispose(processor)
uninitialize(au)
dispose(au)
```

### ✅ For Development and Testing

Use the realtime graph approach in combination with external recording software:

1. Create AudioGraph with your effect chain
2. Synthesize or play test audio via `startgraph!()`
3. Record output using:
   - QuickTime Player (File → New Audio Recording)
   - Audacity
   - System loopback (Soundflower, BlackHole)
4. Analyze the recording

---

## Callback Architecture Details

### How Callbacks Work (Realtime Mode)

```
1. Hardware needs audio (e.g., every 32 samples)
         ↓
2. OS calls AudioUnitRender (with timestamp, bus info)
         ↓
3. AudioUnit needs input - calls YOUR render callback
         ↓
4. Your callback fills AudioBufferList with audio
         ↓
5. AudioUnit processes the audio
         ↓
6. AudioUnitRender returns processed audio
         ↓
7. Hardware sends audio to speakers
         ↓
8. Loop repeats
```

### Callback Registration

```julia
# Store callback function pointer and processor reference
callback_struct = zeros(UInt8, 2 * sizeof(Ptr{Cvoid}))

# Slot 1: Function pointer
unsafe_store!(Ptr{Ptr{Cvoid}}(pointer(callback_struct)),
              Base.unsafe_convert(Ptr{Cvoid}, callback_ptr))

# Slot 2: User data (processor reference)
processor_ptr = pointer_from_objref(processor)
unsafe_store!(Ptr{Ptr{Cvoid}}(pointer(callback_struct) + sizeof(Ptr{Cvoid})),
              processor_ptr)

# Register with AudioUnit
ccall((:AudioUnitSetProperty, AudioToolbox), Int32,
      (Ptr{Cvoid}, UInt32, UInt32, UInt32, Ptr{UInt8}, UInt32),
      au.instance,
      UInt32(23),  # kAudioUnitProperty_SetRenderCallback
      UInt32(1),   # kAudioUnitScope_Input
      UInt32(0),   # element 0
      callback_struct,
      UInt32(sizeof(callback_struct)))
```

### Cleanup

When done, set the callback to NULL:

```julia
null_struct = zeros(UInt8, 2 * sizeof(Ptr{Cvoid}))
ccall((:AudioUnitSetProperty, AudioToolbox), Int32,
      (...),
      au.instance,
      UInt32(23),
      UInt32(1),
      UInt32(0),
      null_struct,
      UInt32(sizeof(null_struct)))
```

---

## Performance Considerations

### Memory Allocation

- **Realtime mode**: No per-frame allocations (handled by framework)
- **AudioProcessor**: Allocates buffers once in constructor; zero allocation during processing
- **Deprecated processbuffer**: Allocated buffers on every call (inefficient)

### Latency

- **Realtime mode**: Hardware determined (typically 5-20ms)
- **AudioProcessor**: CPU-limited (usually <1ms for simple effects)
- **Driven mode**: Not suitable for realtime applications

### CPU Usage

For the same AudioUnit:
- Realtime mode: Optimized by macOS
- AudioProcessor: Single-threaded, synchronous
- Multiple effects chains: Scale linearly with number of units

---

## Migration Guide

### From Deprecated processbuffer

**Old Code**:
```julia
au = load("AULowpass")
initialize(au)

# Each call was separate, inefficient
output1 = processbuffer(au, input1)
output2 = processbuffer(au, input2)

uninitialize(au)
dispose(au)
```

**New Code**:
```julia
au = load("AULowpass")
initialize(au)

# Create processor once, reuse
processor = AudioProcessor(au)
output1 = process(processor, input1)
output2 = process(processor, input2)

dispose(processor)
uninitialize(au)
dispose(au)
```

### For Realtime Use Cases

Switch from driven mode to realtime:

```julia
# Old (unreliable)
for i in 1:100
    output = processbuffer(au, input)  # Discrete calls
end

# New (reliable)
graph = AudioGraph()
node = addnode!(graph, au)
output = addoutputnode!(graph)
connect!(graph, node, output)
initializegraph!(graph)
startgraph!(graph)
sleep(10)  # Audio processes automatically
stopgraph!(graph)
```

---

## Future Improvements

Potential areas for enhancement:

1. **VST Plugin Support**: Consider using VST3 instead of AudioUnits for cross-platform offline processing
2. **Buffer Pool**: Implement buffer pooling for more efficient processing
3. **Multi-threaded Rendering**: Leverage multiple cores for effect chains
4. **State Snapshots**: Save/restore AudioUnit state between processing calls
5. **Validation Layer**: Detect incompatible AudioUnits earlier
6. **Fallback Mechanisms**: Automatic fallback to external tools for unsupported units

---

## Glossary

- **AudioUnit**: Apple's plugin architecture for audio processing
- **AUGraph**: Graph structure connecting multiple AudioUnits
- **Render Callback**: Function called by AudioUnit to request input audio
- **Driven Mode**: Synchronous, buffer-based processing (vs realtime)
- **Buffer List**: C structure holding pointers to audio channel data
- **AudioTimeStamp**: Structure with sample timing information
- **Closure**: Function with captured variables from enclosing scope
- **GC.@preserve**: Julia macro to prevent garbage collection of objects during C calls

---

## References

- [AudioToolbox Framework Documentation](https://developer.apple.com/documentation/audiotoolbox)
- [AudioUnit Programming Guide](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioUnitProgrammingGuide/)
- [SampledSignals.jl](https://github.com/JuliaAudio/SampledSignals.jl)
- [Julia ccall Documentation](https://docs.julialang.org/en/v1/manual/calling-c-and-fortran-code/)
