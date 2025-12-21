# MIDI Example: Playing notes with DLSMusicDevice
#
# This example demonstrates how to send MIDI messages to the Apple DLSMusicDevice
# AudioUnit to play musical notes and melodies.

using AudioUnits

println("AudioUnits.jl - MIDI Example with DLSMusicDevice")
println("=" ^ 70)
println()

# Find the DLSMusicDevice
println("Looking for DLSMusicDevice...")
instruments = find_audiounits(kAudioUnitType_MusicDevice)

dls_device = findfirst(u -> occursin("DLS", u.name), instruments)
if isnothing(dls_device)
    println("DLSMusicDevice not found!")
    println("Available music devices:")
    for inst in instruments
        println("  - ", inst.name)
    end
    exit(1)
end

device_info = instruments[dls_device]
println("Found: ", device_info.name)
println()

# Load and initialize the device
println("Loading and initializing...")
au = load_audiounit(device_info.type, device_info.subtype)
initialize_audiounit(au)
println("AudioUnit initialized: ", au.name)
println()

# Verify MIDI support
if !supports_midi(au)
    println("ERROR: This AudioUnit does not support MIDI!")
    dispose_audiounit(au)
    exit(1)
end
println("✓ MIDI support confirmed")
println()

# NOTE: To actually hear the audio, you would need to:
# 1. Set up an audio output graph (AUGraph)
# 2. Connect the music device to an output unit
# 3. Start the audio processing
#
# This example demonstrates the MIDI message sending only.
# Audio output setup is beyond the current scope but could be added.

println("MIDI Message Examples:")
println("-" ^ 70)

# Example 1: Play a single note
println()
println("Example 1: Playing a single note (middle C)")
println("  Sending Note On: note=60, velocity=100")
note_on(au, 60, 100)
println("  (Note would be playing now if audio output was set up)")

sleep(1.0)  # Simulating note duration

println("  Sending Note Off: note=60")
note_off(au, 60)
println()

# Example 2: Play a chord
println("Example 2: Playing a C major chord (C-E-G)")
println("  Sending Note On for C (60), E (64), G (67)")
note_on(au, 60, 100)  # C
note_on(au, 64, 100)  # E
note_on(au, 67, 100)  # G

sleep(1.5)

println("  Sending Note Off for all notes")
note_off(au, 60)
note_off(au, 64)
note_off(au, 67)
println()

# Example 3: Play a melody (simple scale)
println("Example 3: Playing a C major scale")
scale_notes = [60, 62, 64, 65, 67, 69, 71, 72]  # C D E F G A B C
note_names = ["C", "D", "E", "F", "G", "A", "B", "C"]

for (note, name) in zip(scale_notes, note_names)
    println("  Playing ", name, " (", note, ")")
    note_on(au, note, 100)
    sleep(0.3)
    note_off(au, note)
    sleep(0.1)
end
println()

# Example 4: Change instrument (program change)
println("Example 4: Changing instruments with Program Change")
println("  Current: Acoustic Grand Piano (program 0)")
println("  Changing to: Violin (program 40)")
program_change(au, 40)

println("  Playing a note with violin sound:")
note_on(au, 67, 100)
sleep(1.0)
note_off(au, 67)
println()

# Example 5: Using control changes
println("Example 5: Using MIDI Control Changes")
println("  Setting volume (CC 7) to 80")
control_change(au, 7, 80)

println("  Enabling sustain pedal (CC 64)")
control_change(au, 64, 127)

println("  Playing notes with sustain:")
for note in [60, 64, 67]
    note_on(au, note, 100)
    sleep(0.2)
    note_off(au, note)  # Notes will sustain even after Note Off
end
sleep(1.0)

println("  Releasing sustain pedal")
control_change(au, 64, 0)
println()

# Example 6: Pitch bend
println("Example 6: Using Pitch Bend")
println("  Playing note with pitch bend")
note_on(au, 60, 100)

println("  Bending pitch down...")
for val in range(8192, 4096, length=10)
    pitch_bend(au, Int(round(val)))
    sleep(0.1)
end

println("  Bending pitch back to center...")
for val in range(4096, 8192, length=10)
    pitch_bend(au, Int(round(val)))
    sleep(0.1)
end

note_off(au, 60)
println()

# Example 7: Multiple channels
println("Example 7: Using multiple MIDI channels")
println("  Setting up different instruments on different channels:")
program_change(au, 0, channel=0)   # Piano on channel 0
program_change(au, 40, channel=1)  # Violin on channel 1
program_change(au, 32, channel=2)  # Bass on channel 2

println("  Playing harmony on different channels:")
note_on(au, 48, 100, channel=2)  # Bass note on channel 2
sleep(0.1)
note_on(au, 60, 100, channel=0)  # Piano on channel 0
sleep(0.1)
note_on(au, 67, 100, channel=1)  # Violin on channel 1

sleep(1.5)

all_notes_off(au, channel=0)
all_notes_off(au, channel=1)
all_notes_off(au, channel=2)
println()

# Example 8: Emergency stop - turn off all notes on all channels
println("Example 8: Stopping all notes (panic button)")
println("  Turning off all notes on all channels...")
for ch in 0:15
    all_notes_off(au, channel=ch)
end
println()

# Clean up
println("Cleaning up...")
uninitialize_audiounit(au)
dispose_audiounit(au)
println("Done!")
println()

println("=" ^ 70)
println("MIDI Examples Complete!")
println()
println("Note: To actually hear the audio output, you would need to:")
println("  1. Set up an AUGraph (Audio Unit Graph)")
println("  2. Connect the music device to an output unit")
println("  3. Start the audio processing graph")
println("  4. This would require additional AudioToolbox API calls")
println()
println("The MIDI messages are being sent correctly to the AudioUnit.")
println("In a full audio application, these would generate actual sound.")
