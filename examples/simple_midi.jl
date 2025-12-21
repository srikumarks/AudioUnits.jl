# Simple MIDI Example - Quick Start
#
# This is the simplest way to send MIDI messages to DLSMusicDevice

using AudioUnits

# Load the DLSMusicDevice
au = load("DLSMusicDevice")
initialize(au)

println("Loaded: ", au.name)
println("Supports MIDI: ", supportsmidi(au))

# Play a single note
println("\nPlaying middle C (note 60) for 1 second...")
noteon(au, 60, 100)    # Note On: note=60 (middle C), velocity=100
sleep(1.0)
noteoff(au, 60)        # Note Off: note=60
println("Done!")

# Play a chord
println("\nPlaying C major chord...")
noteon(au, 60, 100)    # C
noteon(au, 64, 100)    # E
noteon(au, 67, 100)    # G
sleep(1.5)
noteoff(au, 60)
noteoff(au, 64)
noteoff(au, 67)

# Change instrument and play
println("\nChanging to Violin (program 40)...")
programchange(au, 40)
noteon(au, 67, 100)
sleep(1.0)
noteoff(au, 67)

# Clean up
uninitialize(au)
dispose(au)

println("\nNote: MIDI messages are being sent, but you won't hear audio")
println("without setting up an audio output graph (AUGraph).")
