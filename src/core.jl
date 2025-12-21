# Core AudioUnit functionality

"""
    find_audiounits(type::Union{AudioUnitType, Nothing} = nothing) -> Vector{AudioUnitInfo}

Find all available AudioUnits on the system. Optionally filter by type.

Returns a vector of `AudioUnitInfo` structs with fields:
- `name`: The AudioUnit name
- `manufacturer`: The manufacturer name
- `type`: The AudioUnitType
- `subtype`: The subtype identifier
- `version`: Version number

# Examples
```julia
# Find all AudioUnits
all_units = find_audiounits()

# Find only effect units
effects = find_audiounits(kAudioUnitType_Effect)

# Find music devices (instruments)
instruments = find_audiounits(kAudioUnitType_MusicDevice)
```
"""
function find_audiounits(type::Union{AudioUnitType, Nothing} = nothing)
    units = AudioUnitInfo[]

    # Create search description
    desc = if isnothing(type)
        AudioComponentDescription(0, 0, 0, 0, 0)
    else
        AudioComponentDescription(UInt32(type), 0, 0, 0, 0)
    end

    component = Ref{Ptr{Cvoid}}(C_NULL)

    # Iterate through all matching components
    while true
        component[] = ccall((:AudioComponentFindNext, AudioToolbox), Ptr{Cvoid},
                           (Ptr{Cvoid}, Ref{AudioComponentDescription}),
                           component[], Ref(desc))

        if component[] == C_NULL
            break
        end

        # Get component description
        comp_desc = Ref{AudioComponentDescription}()
        status = ccall((:AudioComponentGetDescription, AudioToolbox), Int32,
                      (Ptr{Cvoid}, Ref{AudioComponentDescription}),
                      component[], comp_desc)

        if status != noErr
            continue
        end

        # Get component name
        name = get_component_name(component[])
        manufacturer = get_component_manufacturer(component[])
        version = get_component_version(component[])

        # Determine AudioUnitType
        au_type = try
            AudioUnitType(comp_desc[].componentType)
        catch
            continue  # Skip unknown types
        end

        push!(units, AudioUnitInfo(
            name,
            manufacturer,
            au_type,
            comp_desc[].componentSubType,
            version
        ))
    end

    return units
end

"""
    load_audiounit(name::String) -> AudioUnit
    load_audiounit(type::AudioUnitType, subtype::UInt32) -> AudioUnit

Load an AudioUnit by name or by type and subtype.

# Examples
```julia
# Load by name
au = load_audiounit("AULowpass")

# Load by type and subtype
au = load_audiounit(kAudioUnitType_Effect, 0x6c706173)  # 'lpas'
```
"""
function load_audiounit(name::String)
    units = find_audiounits()
    idx = findfirst(u -> u.name == name, units)

    if isnothing(idx)
        error("AudioUnit '$name' not found")
    end

    unit = units[idx]
    return load_audiounit(unit.type, unit.subtype)
end

function load_audiounit(type::AudioUnitType, subtype::UInt32)
    # Create search description
    desc = AudioComponentDescription(UInt32(type), subtype, 0, 0, 0)

    # Find the component
    component = ccall((:AudioComponentFindNext, AudioToolbox), Ptr{Cvoid},
                     (Ptr{Cvoid}, Ref{AudioComponentDescription}),
                     C_NULL, Ref(desc))

    if component == C_NULL
        error("AudioUnit with type $(type) and subtype $(subtype) not found")
    end

    # Create an instance
    instance = Ref{Ptr{Cvoid}}()
    status = ccall((:AudioComponentInstanceNew, AudioToolbox), Int32,
                  (Ptr{Cvoid}, Ptr{Ptr{Cvoid}}),
                  component, instance)

    if status != noErr
        error("Failed to create AudioUnit instance: OSStatus $status")
    end

    # Get component info
    name = get_component_name(component)
    manufacturer = get_component_manufacturer(component)
    version = get_component_version(component)

    return AudioUnit(component, instance[], name, manufacturer, version, type, subtype)
end

"""
    initialize_audiounit(au::AudioUnit) -> Bool

Initialize an AudioUnit for processing. Must be called before using the unit.

Returns `true` on success, `false` otherwise.
"""
function initialize_audiounit(au::AudioUnit)
    if au.initialized
        @warn "AudioUnit already initialized"
        return true
    end

    status = ccall((:AudioUnitInitialize, AudioToolbox), Int32,
                  (Ptr{Cvoid},), au.instance)

    if status == noErr
        au.initialized = true
        return true
    else
        @error "Failed to initialize AudioUnit: OSStatus $status"
        return false
    end
end

"""
    uninitialize_audiounit(au::AudioUnit) -> Bool

Uninitialize an AudioUnit. Can be called before reconfiguring parameters.

Returns `true` on success, `false` otherwise.
"""
function uninitialize_audiounit(au::AudioUnit)
    if !au.initialized
        return true
    end

    status = ccall((:AudioUnitUninitialize, AudioToolbox), Int32,
                  (Ptr{Cvoid},), au.instance)

    if status == noErr
        au.initialized = false
        return true
    else
        @error "Failed to uninitialize AudioUnit: OSStatus $status"
        return false
    end
end

"""
    dispose_audiounit(au::AudioUnit)

Dispose of an AudioUnit instance and free its resources.
"""
function dispose_audiounit(au::AudioUnit)
    if au.initialized
        uninitialize_audiounit(au)
    end

    if au.instance != C_NULL
        ccall((:AudioComponentInstanceDispose, AudioToolbox), Int32,
              (Ptr{Cvoid},), au.instance)
        au.instance = C_NULL
    end
end

# Helper functions

function get_component_name(component::Ptr{Cvoid})::String
    name_ref = Ref{Ptr{Cvoid}}()
    status = ccall((:AudioComponentCopyName, AudioToolbox), Int32,
                  (Ptr{Cvoid}, Ptr{Ptr{Cvoid}}),
                  component, name_ref)

    if status != noErr || name_ref[] == C_NULL
        return "Unknown"
    end

    # Get CFString as Julia string
    cf_string = name_ref[]
    length = ccall(:CFStringGetLength, Clong, (Ptr{Cvoid},), cf_string)

    if length == 0
        ccall(:CFRelease, Cvoid, (Ptr{Cvoid},), cf_string)
        return "Unknown"
    end

    # Get C string
    c_str = ccall(:CFStringGetCStringPtr, Ptr{UInt8},
                 (Ptr{Cvoid}, UInt32), cf_string, 0x08000100)  # kCFStringEncodingUTF8

    if c_str == C_NULL
        # Fallback: copy to buffer
        buffer = Vector{UInt8}(undef, length * 3 + 1)  # UTF-8 can use up to 3 bytes per char
        success = ccall(:CFStringGetCString, Bool,
                       (Ptr{Cvoid}, Ptr{UInt8}, Clong, UInt32),
                       cf_string, buffer, length * 3 + 1, 0x08000100)
        ccall(:CFRelease, Cvoid, (Ptr{Cvoid},), cf_string)
        return success ? unsafe_string(pointer(buffer)) : "Unknown"
    end

    result = unsafe_string(c_str)
    ccall(:CFRelease, Cvoid, (Ptr{Cvoid},), cf_string)
    return result
end

function get_component_manufacturer(component::Ptr{Cvoid})::String
    # Get component description
    desc = Ref{AudioComponentDescription}()
    status = ccall((:AudioComponentGetDescription, AudioToolbox), Int32,
                  (Ptr{Cvoid}, Ref{AudioComponentDescription}),
                  component, desc)

    if status != noErr
        return "Unknown"
    end

    # Convert manufacturer code to string (FourCC)
    mfr = desc[].componentManufacturer
    if mfr == 0
        return "Unknown"
    end

    return fourcc_to_string(mfr)
end

function get_component_version(component::Ptr{Cvoid})::UInt32
    version = Ref{UInt32}()
    status = ccall((:AudioComponentGetVersion, AudioToolbox), Int32,
                  (Ptr{Cvoid}, Ptr{UInt32}),
                  component, version)

    return status == noErr ? version[] : 0
end

function fourcc_to_string(code::UInt32)::String
    chars = [
        Char((code >> 24) & 0xFF),
        Char((code >> 16) & 0xFF),
        Char((code >> 8) & 0xFF),
        Char(code & 0xFF)
    ]
    return String(chars)
end

function string_to_fourcc(s::String)::UInt32
    if length(s) != 4
        error("FourCC string must be exactly 4 characters")
    end

    bytes = codeunits(s)
    return (UInt32(bytes[1]) << 24) |
           (UInt32(bytes[2]) << 16) |
           (UInt32(bytes[3]) << 8) |
           UInt32(bytes[4])
end
