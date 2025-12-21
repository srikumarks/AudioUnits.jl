# MIDI functionality for AudioUnits

"""
    sendmidi(au::AudioUnit, status::UInt8, data1::UInt8, data2::UInt8)

Send a MIDI event to a music device AudioUnit.

# Arguments
- `au::AudioUnit`: The AudioUnit to send MIDI to (must support MIDI)
- `status::UInt8`: MIDI status byte (includes message type and channel)
- `data1::UInt8`: First data byte
- `data2::UInt8`: Second data byte

# MIDI Message Format
The status byte contains:
- Upper nibble (4 bits): Message type
- Lower nibble (4 bits): MIDI channel (0-15)

Common MIDI messages:
- 0x90: Note On (data1=note, data2=velocity)
- 0x80: Note Off (data1=note, data2=velocity)
- 0xB0: Control Change (data1=controller, data2=value)
- 0xC0: Program Change (data1=program)
- 0xE0: Pitch Bend (data1=LSB, data2=MSB)

# Examples
```julia
au = load("DLSMusicDevice")
initialize(au)

# Send Note On for middle C (60) with velocity 100 on channel 0
sendmidi(au, 0x90, 60, 100)

# Send Note Off for middle C
sendmidi(au, 0x80, 60, 0)
```
"""
function sendmidi(au::AudioUnit, status::UInt8, data1::UInt8, data2::UInt8)
    if !supportsmidi(au)
        error("AudioUnit $(au.name) does not support MIDI input")
    end

    if !au.initialized
        error("AudioUnit must be initialized before sending MIDI events")
    end

    # Call MusicDeviceMIDIEvent
    # OSStatus MusicDeviceMIDIEvent(MusicDeviceComponent inUnit,
    #                               UInt32 inStatus,
    #                               UInt32 inData1,
    #                               UInt32 inData2,
    #                               UInt32 inOffsetSampleFrame)
    status_code = ccall((:MusicDeviceMIDIEvent, AudioToolbox), Int32,
                       (Ptr{Cvoid}, UInt32, UInt32, UInt32, UInt32),
                       au.instance, UInt32(status), UInt32(data1), UInt32(data2), 0)

    if status_code != noErr
        error("Failed to send MIDI event: OSStatus $status_code")
    end

    return true
end

"""
    noteon(au::AudioUnit, note::Integer, velocity::Integer=100; channel::Integer=0)

Send a MIDI Note On message.

# Arguments
- `au::AudioUnit`: The AudioUnit to send to
- `note::Integer`: MIDI note number (0-127, middle C = 60)
- `velocity::Integer`: Note velocity (0-127, default=100)
- `channel::Integer`: MIDI channel (0-15, default=0)

# Examples
```julia
# Play middle C at velocity 100 on channel 0
noteon(au, 60)

# Play A above middle C at velocity 64 on channel 1
noteon(au, 69, 64, channel=1)
```
"""
function noteon(au::AudioUnit, note::Integer, velocity::Integer=100; channel::Integer=0)
    if note < 0 || note > 127
        error("Note must be in range 0-127, got $note")
    end
    if velocity < 0 || velocity > 127
        error("Velocity must be in range 0-127, got $velocity")
    end
    if channel < 0 || channel > 15
        error("Channel must be in range 0-15, got $channel")
    end

    status = UInt8(0x90 | (channel & 0x0F))
    return sendmidi(au, status, UInt8(note), UInt8(velocity))
end

"""
    noteoff(au::AudioUnit, note::Integer; channel::Integer=0)

Send a MIDI Note Off message.

# Arguments
- `au::AudioUnit`: The AudioUnit to send to
- `note::Integer`: MIDI note number (0-127)
- `channel::Integer`: MIDI channel (0-15, default=0)

# Examples
```julia
# Stop middle C on channel 0
noteoff(au, 60)

# Stop A above middle C on channel 1
noteoff(au, 69, channel=1)
```
"""
function noteoff(au::AudioUnit, note::Integer; channel::Integer=0)
    if note < 0 || note > 127
        error("Note must be in range 0-127, got $note")
    end
    if channel < 0 || channel > 15
        error("Channel must be in range 0-15, got $channel")
    end

    status = UInt8(0x80 | (channel & 0x0F))
    return sendmidi(au, status, UInt8(note), UInt8(0))
end

"""
    controlchange(au::AudioUnit, controller::Integer, value::Integer; channel::Integer=0)

Send a MIDI Control Change message.

# Arguments
- `au::AudioUnit`: The AudioUnit to send to
- `controller::Integer`: Controller number (0-127)
- `value::Integer`: Controller value (0-127)
- `channel::Integer`: MIDI channel (0-15, default=0)

Common controllers:
- 1: Modulation
- 7: Volume
- 10: Pan
- 64: Sustain Pedal
- 121: Reset All Controllers

# Examples
```julia
# Set volume to 100 on channel 0
controlchange(au, 7, 100)

# Enable sustain pedal on channel 1
controlchange(au, 64, 127, channel=1)
```
"""
function controlchange(au::AudioUnit, controller::Integer, value::Integer; channel::Integer=0)
    if controller < 0 || controller > 127
        error("Controller must be in range 0-127, got $controller")
    end
    if value < 0 || value > 127
        error("Value must be in range 0-127, got $value")
    end
    if channel < 0 || channel > 15
        error("Channel must be in range 0-15, got $channel")
    end

    status = UInt8(0xB0 | (channel & 0x0F))
    return sendmidi(au, status, UInt8(controller), UInt8(value))
end

"""
    programchange(au::AudioUnit, program::Integer; channel::Integer=0)

Send a MIDI Program Change message to change the instrument/preset.

# Arguments
- `au::AudioUnit`: The AudioUnit to send to
- `program::Integer`: Program number (0-127)
- `channel::Integer`: MIDI channel (0-15, default=0)

# Examples
```julia
# Change to program 0 (usually Acoustic Grand Piano)
programchange(au, 0)

# Change to program 40 (usually Violin) on channel 1
programchange(au, 40, channel=1)
```
"""
function programchange(au::AudioUnit, program::Integer; channel::Integer=0)
    if program < 0 || program > 127
        error("Program must be in range 0-127, got $program")
    end
    if channel < 0 || channel > 15
        error("Channel must be in range 0-15, got $channel")
    end

    status = UInt8(0xC0 | (channel & 0x0F))
    return sendmidi(au, status, UInt8(program), UInt8(0))
end

"""
    pitchbend(au::AudioUnit, value::Integer; channel::Integer=0)

Send a MIDI Pitch Bend message.

# Arguments
- `au::AudioUnit`: The AudioUnit to send to
- `value::Integer`: Pitch bend value (0-16383, center=8192)
- `channel::Integer`: MIDI channel (0-15, default=0)

# Examples
```julia
# Center pitch (no bend)
pitchbend(au, 8192)

# Bend up
pitchbend(au, 12288)

# Bend down
pitchbend(au, 4096)
```
"""
function pitchbend(au::AudioUnit, value::Integer; channel::Integer=0)
    if value < 0 || value > 16383
        error("Pitch bend value must be in range 0-16383, got $value")
    end
    if channel < 0 || channel > 15
        error("Channel must be in range 0-15, got $channel")
    end

    status = UInt8(0xE0 | (channel & 0x0F))
    lsb = UInt8(value & 0x7F)
    msb = UInt8((value >> 7) & 0x7F)
    return sendmidi(au, status, lsb, msb)
end

"""
    allnotesoff(au::AudioUnit; channel::Integer=0)

Turn off all notes on a MIDI channel.

# Arguments
- `au::AudioUnit`: The AudioUnit to send to
- `channel::Integer`: MIDI channel (0-15, default=0)

# Examples
```julia
# Stop all notes on channel 0
allnotesoff(au)

# Stop all notes on all channels
for ch in 0:15
    allnotesoff(au, channel=ch)
end
```
"""
function allnotesoff(au::AudioUnit; channel::Integer=0)
    if channel < 0 || channel > 15
        error("Channel must be in range 0-15, got $channel")
    end

    # CC 123 = All Notes Off
    return controlchange(au, 123, 0, channel=channel)
end
