# MIDI functionality for AudioUnits

"""
    sendmidi(au::AudioUnit, status::UInt8, data1::UInt8, data2::UInt8; offset::UInt32=0)

Send a MIDI event to a music device AudioUnit with optional sample-accurate timing.

# Arguments
- `au::AudioUnit`: The AudioUnit to send MIDI to (must support MIDI)
- `status::UInt8`: MIDI status byte (includes message type and channel)
- `data1::UInt8`: First data byte
- `data2::UInt8`: Second data byte
- `offset::UInt32`: Sample offset within the current render block (default: 0, immediate)

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

# Sample Offset Timing
The `offset` parameter allows sample-accurate scheduling within a render block:
- 0 = immediate/start of block (default)
- 100 = 100 samples into the block (~2.3ms at 44.1kHz)
- Provides timing precision of ~23 microseconds at 44.1kHz

# Examples
```julia
au = load("DLSMusicDevice")
initialize(au)

# Send Note On for middle C (60) with velocity 100 on channel 0 (immediate)
sendmidi(au, 0x90, 60, 100)

# Send Note Off for middle C at sample 256 in the current render block
sendmidi(au, 0x80, 60, 0; offset=256)
```
"""
function sendmidi(au::AudioUnit, status::UInt8, data1::UInt8, data2::UInt8; offset::UInt32=0)
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
                       au.instance, UInt32(status), UInt32(data1), UInt32(data2), offset)

    if status_code != noErr
        error("Failed to send MIDI event: OSStatus $status_code")
    end

    return true
end

"""
    noteon(au::AudioUnit, channel::Integer, note::Integer, velocity::Integer=100; offset::UInt32=0)

Send a MIDI Note On message.

# Arguments
- `au::AudioUnit`: The AudioUnit to send to
- `channel::Integer`: MIDI channel (0-15)
- `note::Integer`: MIDI note number (0-127, middle C = 60)
- `velocity::Integer`: Note velocity (0-127, default=100)
- `offset::UInt32`: Sample offset within the render block (default: 0, immediate)

# Examples
```julia
# Play middle C at velocity 100 on channel 0 (immediate)
noteon(au, 0, 60)

# Play A above middle C at sample offset 256
noteon(au, 1, 69, 64, offset=256)
```
"""
function noteon(au::AudioUnit, channel::Integer, note::Integer, velocity::Integer=100; offset::UInt32=0)
    @assert 0 <= channel <= 15 "Channel must be in range 0-15, got $channel"
    @assert 0 <= note <= 127 "Note must be in range 0-127, got $note"
    @assert 0 <= velocity <= 127 "Velocity must be in range 0-127, got $velocity"

    status = UInt8(0x90 | (channel & 0x0F))
    return sendmidi(au, status, UInt8(note), UInt8(velocity); offset=offset)
end

"""
    noteoff(au::AudioUnit, channel::Integer, note::Integer; offset::UInt32=0)

Send a MIDI Note Off message.

# Arguments
- `au::AudioUnit`: The AudioUnit to send to
- `channel::Integer`: MIDI channel (0-15)
- `note::Integer`: MIDI note number (0-127)
- `offset::UInt32`: Sample offset within the render block (default: 0, immediate)

# Examples
```julia
# Stop middle C on channel 0
noteoff(au, 0, 60)

# Stop A above middle C at sample offset 512
noteoff(au, 1, 69, offset=512)
```
"""
function noteoff(au::AudioUnit, channel::Integer, note::Integer; offset::UInt32=0)
    @assert 0 <= channel <= 15 "Channel must be in range 0-15, got $channel"
    @assert 0 <= note <= 127 "Note must be in range 0-127, got $note"

    status = UInt8(0x80 | (channel & 0x0F))
    return sendmidi(au, status, UInt8(note), UInt8(0); offset=offset)
end

"""
    controlchange(au::AudioUnit, channel::Integer, controller::Integer, value::Integer; offset::UInt32=0)

Send a MIDI Control Change message.

# Arguments
- `au::AudioUnit`: The AudioUnit to send to
- `channel::Integer`: MIDI channel (0-15)
- `controller::Integer`: Controller number (0-127)
- `value::Integer`: Controller value (0-127)
- `offset::UInt32`: Sample offset within the render block (default: 0, immediate)

Common controllers:
- 1: Modulation
- 7: Volume
- 10: Pan
- 64: Sustain Pedal
- 121: Reset All Controllers

# Examples
```julia
# Set volume to 100 on channel 0
controlchange(au, 0, 7, 100)

# Enable sustain pedal at sample 256
controlchange(au, 1, 64, 127, offset=256)
```
"""
function controlchange(au::AudioUnit, channel::Integer, controller::Integer, value::Integer; offset::UInt32=0)
    @assert 0 <= channel <= 15 "Channel must be in range 0-15, got $channel"
    @assert 0 <= controller <= 127 "Controller must be in range 0-127, got $controller"
    @assert 0 <= value <= 127 "Value must be in range 0-127, got $value"

    status = UInt8(0xB0 | (channel & 0x0F))
    return sendmidi(au, status, UInt8(controller), UInt8(value); offset=offset)
end

"""
    programchange(au::AudioUnit, channel::Integer, program::Integer; offset::UInt32=0)

Send a MIDI Program Change message to change the instrument/preset.

# Arguments
- `au::AudioUnit`: The AudioUnit to send to
- `channel::Integer`: MIDI channel (0-15)
- `program::Integer`: Program number (0-127)
- `offset::UInt32`: Sample offset within the render block (default: 0, immediate)

# Examples
```julia
# Change to program 0 (usually Acoustic Grand Piano) on channel 0
programchange(au, 0, 0)

# Change to program 40 (usually Violin) on channel 1 at sample offset 256
programchange(au, 1, 40, offset=256)
```
"""
function programchange(au::AudioUnit, channel::Integer, program::Integer; offset::UInt32=0)
    @assert 0 <= channel <= 15 "Channel must be in range 0-15, got $channel"
    @assert 0 <= program <= 127 "Program must be in range 0-127, got $program"

    status = UInt8(0xC0 | (channel & 0x0F))
    return sendmidi(au, status, UInt8(program), UInt8(0); offset=offset)
end

"""
    pitchbend(au::AudioUnit, channel::Integer, value::Integer; offset::UInt32=0)

Send a MIDI Pitch Bend message.

# Arguments
- `au::AudioUnit`: The AudioUnit to send to
- `channel::Integer`: MIDI channel (0-15)
- `value::Integer`: Pitch bend value (0-16383, center=8192)
- `offset::UInt32`: Sample offset within the render block (default: 0, immediate)

# Examples
```julia
# Center pitch (no bend) on channel 0
pitchbend(au, 0, 8192)

# Bend up at sample offset 256
pitchbend(au, 0, 12288, offset=256)

# Bend down at sample offset 512
pitchbend(au, 0, 4096, offset=512)
```
"""
function pitchbend(au::AudioUnit, channel::Integer, value::Integer; offset::UInt32=0)
    @assert 0 <= channel <= 15 "Channel must be in range 0-15, got $channel"
    @assert 0 <= value <= 16383 "Pitch bend value must be in range 0-16383, got $value"

    status = UInt8(0xE0 | (channel & 0x0F))
    lsb = UInt8(value & 0x7F)
    msb = UInt8((value >> 7) & 0x7F)
    return sendmidi(au, status, lsb, msb; offset=offset)
end

"""
    allnotesoff(au::AudioUnit, channel::Integer; offset::UInt32=0)

Turn off all notes on a MIDI channel.

# Arguments
- `au::AudioUnit`: The AudioUnit to send to
- `channel::Integer`: MIDI channel (0-15)
- `offset::UInt32`: Sample offset within the render block (default: 0, immediate)

# Examples
```julia
# Stop all notes on channel 0
allnotesoff(au, 0)

# Stop all notes on all channels at sample offset 512
for ch in 0:15
    allnotesoff(au, ch, offset=512)
end
```
"""
function allnotesoff(au::AudioUnit, channel::Integer; offset::UInt32=0)
    @assert 0 <= channel <= 15 "Channel must be in range 0-15, got $channel"

    # CC 123 = All Notes Off
    return controlchange(au, channel, 123, 0, offset=offset)
end
