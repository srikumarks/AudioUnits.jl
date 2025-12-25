# MIDI functionality for AUv3 AudioUnits
#
# AUv3 MIDI support is implemented through audio block parameters and scheduled events.
# For Phase 6, we provide a simplified event queue approach.
# Full AURenderEvent support will be implemented in later phases.

"""
    sendmidi(au::AudioUnit, status::UInt8, data1::UInt8, data2::UInt8; offset::UInt32=0)

Send a MIDI event to a music device AudioUnit with optional sample-accurate timing.

**Note:** AUv3 MIDI support via block parameters is Phase 6 work.
Currently returns false with a warning.

# Arguments
- `au::AudioUnit`: The AudioUnit to send MIDI to (must support MIDI)
- `status::UInt8`: MIDI status byte (includes message type and channel)
- `data1::UInt8`: First data byte
- `data2::UInt8`: Second data byte
- `offset::UInt32`: Sample offset within the current render block (default: 0, immediate)

# Examples
```julia
au = load("AULowpass")
initialize(au)

# MIDI support coming in Phase 6
sendmidi(au, 0x90, 60, 100)
```
"""
function sendmidi(au::AudioUnit, status::UInt8, data1::UInt8, data2::UInt8; offset::UInt32=UInt32(0))
    if !supportsmidi(au)
        error("AudioUnit $(au.name) does not support MIDI input")
    end

    if !au.initialized
        error("AudioUnit must be initialized before sending MIDI events")
    end

    @warn "MIDI support for AUv3 is not yet fully implemented (Phase 6 work)"
    return false
end

"""
    noteon(au::AudioUnit, channel::Integer, note::Integer, velocity::Integer=100; offset::UInt32=0)

Send a MIDI Note On message.

**Note:** AUv3 MIDI support is Phase 6 work. Currently returns false with a warning.

# Arguments
- `au::AudioUnit`: The AudioUnit to send to
- `channel::Integer`: MIDI channel (0-15)
- `note::Integer`: MIDI note number (0-127, middle C = 60)
- `velocity::Integer`: Note velocity (0-127, default=100)
- `offset::UInt32`: Sample offset within the render block (default: 0, immediate)
"""
function noteon(au::AudioUnit, channel::Integer, note::Integer, velocity::Integer=100; offset::UInt32=UInt32(0))
    @assert 0 <= channel <= 15 "Channel must be in range 0-15, got $channel"
    @assert 0 <= note <= 127 "Note must be in range 0-127, got $note"
    @assert 0 <= velocity <= 127 "Velocity must be in range 0-127, got $velocity"

    status = UInt8(0x90 | (channel & 0x0F))
    return sendmidi(au, status, UInt8(note), UInt8(velocity); offset=offset)
end

"""
    noteoff(au::AudioUnit, channel::Integer, note::Integer; offset::UInt32=0)

Send a MIDI Note Off message.

**Note:** AUv3 MIDI support is Phase 6 work. Currently returns false with a warning.

# Arguments
- `au::AudioUnit`: The AudioUnit to send to
- `channel::Integer`: MIDI channel (0-15)
- `note::Integer`: MIDI note number (0-127)
- `offset::UInt32`: Sample offset within the render block (default: 0, immediate)
"""
function noteoff(au::AudioUnit, channel::Integer, note::Integer; offset::UInt32=UInt32(0))
    @assert 0 <= channel <= 15 "Channel must be in range 0-15, got $channel"
    @assert 0 <= note <= 127 "Note must be in range 0-127, got $note"

    status = UInt8(0x80 | (channel & 0x0F))
    return sendmidi(au, status, UInt8(note), UInt8(0); offset=offset)
end

"""
    controlchange(au::AudioUnit, channel::Integer, controller::Integer, value::Integer; offset::UInt32=0)

Send a MIDI Control Change message.

**Note:** AUv3 MIDI support is Phase 6 work. Currently returns false with a warning.

# Arguments
- `au::AudioUnit`: The AudioUnit to send to
- `channel::Integer`: MIDI channel (0-15)
- `controller::Integer`: Controller number (0-127)
- `value::Integer`: Controller value (0-127)
- `offset::UInt32`: Sample offset within the render block (default: 0, immediate)
"""
function controlchange(au::AudioUnit, channel::Integer, controller::Integer, value::Integer; offset::UInt32=UInt32(0))
    @assert 0 <= channel <= 15 "Channel must be in range 0-15, got $channel"
    @assert 0 <= controller <= 127 "Controller must be in range 0-127, got $controller"
    @assert 0 <= value <= 127 "Value must be in range 0-127, got $value"

    status = UInt8(0xB0 | (channel & 0x0F))
    return sendmidi(au, status, UInt8(controller), UInt8(value); offset=offset)
end

"""
    programchange(au::AudioUnit, channel::Integer, program::Integer; offset::UInt32=0)

Send a MIDI Program Change message to change the instrument/preset.

**Note:** AUv3 MIDI support is Phase 6 work. Currently returns false with a warning.

# Arguments
- `au::AudioUnit`: The AudioUnit to send to
- `channel::Integer`: MIDI channel (0-15)
- `program::Integer`: Program number (0-127)
- `offset::UInt32`: Sample offset within the render block (default: 0, immediate)
"""
function programchange(au::AudioUnit, channel::Integer, program::Integer; offset::UInt32=UInt32(0))
    @assert 0 <= channel <= 15 "Channel must be in range 0-15, got $channel"
    @assert 0 <= program <= 127 "Program must be in range 0-127, got $program"

    status = UInt8(0xC0 | (channel & 0x0F))
    return sendmidi(au, status, UInt8(program), UInt8(0); offset=offset)
end

"""
    pitchbend(au::AudioUnit, channel::Integer, value::Integer; offset::UInt32=0)

Send a MIDI Pitch Bend message.

**Note:** AUv3 MIDI support is Phase 6 work. Currently returns false with a warning.

# Arguments
- `au::AudioUnit`: The AudioUnit to send to
- `channel::Integer`: MIDI channel (0-15)
- `value::Integer`: Pitch bend value (0-16383, center=8192)
- `offset::UInt32`: Sample offset within the render block (default: 0, immediate)
"""
function pitchbend(au::AudioUnit, channel::Integer, value::Integer; offset::UInt32=UInt32(0))
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

**Note:** AUv3 MIDI support is Phase 6 work. Currently returns false with a warning.

# Arguments
- `au::AudioUnit`: The AudioUnit to send to
- `channel::Integer`: MIDI channel (0-15)
- `offset::UInt32`: Sample offset within the render block (default: 0, immediate)
"""
function allnotesoff(au::AudioUnit, channel::Integer; offset::UInt32=UInt32(0))
    @assert 0 <= channel <= 15 "Channel must be in range 0-15, got $channel"

    # CC 123 = All Notes Off
    return controlchange(au, channel, 123, 0, offset=offset)
end
