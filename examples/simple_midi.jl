# Simple MIDI Example - Quick Start
#
# This is the simplest way to send MIDI messages to DLSMusicDevice

using AudioUnits

# Load the DLSMusicDevice
au = load_audiounit("DLSMusicDevice")
initialize_audiounit(au)

println("Loaded: ", au.name)
println("Supports MIDI: ", supports_midi(au))

# Play a single note
println("\nPlaying middle C (note 60) for 1 second...")
note_on(au, 60, 100)    # Note On: note=60 (middle C), velocity=100
sleep(1.0)
note_off(au, 60)        # Note Off: note=60
println("Done!")

# Play a chord
println("\nPlaying C major chord...")
note_on(au, 60, 100)    # C
note_on(au, 64, 100)    # E
note_on(au, 67, 100)    # G
sleep(1.5)
note_off(au, 60)
note_off(au, 64)
note_off(au, 67)

# Change instrument and play
println("\nChanging to Violin (program 40)...")
program_change(au, 40)
note_on(au, 67, 100)
sleep(1.0)
note_off(au, 67)

# Clean up
uninitialize_audiounit(au)
dispose_audiounit(au)

println("\nNote: MIDI messages are being sent, but you won't hear audio")
println("without setting up an audio output graph (AUGraph).")
