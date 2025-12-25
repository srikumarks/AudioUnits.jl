# Core AudioUnit functionality for AUv3

"""
    issupported() -> Bool

Check whether AudioUnits are supported on the current platform.

AudioUnits are only available on macOS (Apple platforms). This function returns
`true` on macOS and `false` on all other platforms.

The AudioUnits.jl package can be imported on any platform, but attempting to use
AudioUnit functionality on non-Apple platforms will result in errors. Use this
function to check platform support before calling other AudioUnits methods.

# Examples
```julia
using AudioUnits

if issupported()
    # Safe to use AudioUnits functionality
    units = findaudiounits()
    println("Found ", length(units), " AudioUnits")
else
    println("AudioUnits not supported on this platform")
end
```
"""
function issupported()
    return Sys.isapple()
end

"""
    findaudiounits(type::Union{AudioUnitType, Nothing} = nothing) -> Vector{AudioUnitInfo}

Find all available AudioUnits on the system. Optionally filter by type.

Uses AVAudioUnitComponentManager (AUv3 API) to discover components.

Returns a vector of `AudioUnitInfo` structs with fields:
- `name`: The AudioUnit name
- `manufacturer`: The manufacturer name
- `type`: The AudioUnitType
- `subtype`: The subtype identifier
- `version`: Version number

# Examples
```julia
# Find all AudioUnits
all_units = findaudiounits()

# Find only effect units
effects = findaudiounits(kAudioUnitType_Effect)

# Find music devices (instruments)
instruments = findaudiounits(kAudioUnitType_MusicDevice)
```
"""
function findaudiounits(type::Union{AudioUnitType, Nothing} = nothing)
    units = AudioUnitInfo[]

    if !issupported()
        @warn "AudioUnits are not supported on this platform"
        return units
    end

    # Get the shared component manager (AUv3 API)
    manager = ObjectiveC.msgSend(
        AVAudioUnitComponentManager,
        "sharedAudioUnitComponentManager",
        ObjectiveC.Object
    )

    if isnothing(manager) || manager == C_NULL
        @error "Failed to get AVAudioUnitComponentManager"
        return units
    end

    # Get array of components
    components = if isnothing(type)
        # Get all components
        ObjectiveC.msgSend(manager, "components", ObjectiveC.Object)
    else
        # Create a description for filtering
        type_code = UInt32(type)
        desc = create_audio_component_description(type_code, 0, 0)

        # Get components matching description
        ObjectiveC.msgSend(
            manager,
            "componentsMatchingDescription:",
            desc,
            ObjectiveC.Object
        )
    end

    if isnothing(components) || components == C_NULL
        return units
    end

    # Convert ObjC array to Julia Vector
    components_array = objc_array_to_julia(components)

    # Process each component
    for component_obj in components_array
        try
            info = extract_audiounit_info(component_obj)
            if !isnothing(info)
                push!(units, info)
            end
        catch e
            @debug "Failed to extract AudioUnit info: $e"
            continue
        end
    end

    return units
end

"""
    load(name::String) -> AudioUnit
    load(type::AudioUnitType, subtype::UInt32) -> AudioUnit

Load an AudioUnit by name or by type and subtype.

Note: Loading is asynchronous in AUv3, but this function provides a synchronous
Julia API by using a completion handler and waiting for the result.

# Examples
```julia
# Load by name
au = load("AULowpass")

# Load by type and subtype
au = load(kAudioUnitType_Effect, 0x6c706173)  # 'lpas'
```
"""
function load(name::String)
    units = findaudiounits()
    idx = findfirst(u -> u.name == name, units)

    if isnothing(idx)
        error("AudioUnit '$name' not found")
    end

    unit = units[idx]
    return load(unit.type, unit.subtype)
end

function load(type::AudioUnitType, subtype::UInt32)
    if !issupported()
        error("AudioUnits not supported on this platform")
    end

    # Get the shared component manager
    manager = ObjectiveC.msgSend(
        AVAudioUnitComponentManager,
        "sharedAudioUnitComponentManager",
        ObjectiveC.Object
    )

    if isnothing(manager) || manager == C_NULL
        error("Failed to get AVAudioUnitComponentManager")
    end

    # Create a description for the component we want to load
    type_code = UInt32(type)
    desc = create_audio_component_description(type_code, subtype, 0)

    # Find matching components
    components = ObjectiveC.msgSend(
        manager,
        "componentsMatchingDescription:",
        desc,
        ObjectiveC.Object
    )

    if isnothing(components) || components == C_NULL
        error("AudioUnit with type $(type) and subtype $(subtype) not found")
    end

    # Get first component
    components_array = objc_array_to_julia(components)
    if isempty(components_array)
        error("AudioUnit with type $(type) and subtype $(subtype) not found")
    end

    component_obj = components_array[1]

    # Extract component info for AudioUnit struct
    info = extract_audiounit_info(component_obj)
    if isnothing(info)
        error("Failed to extract AudioUnit information")
    end

    # Asynchronously instantiate the AudioUnit
    # We wrap the async call synchronously using objc_await
    au_instance = objc_await() do completion_handler
        # Create completion block
        block = ObjectiveC.@block (au::ObjectiveC.Object, err::ObjectiveC.Object) -> begin
            completion_handler(au, err)
            return nothing
        end

        # Call async instantiation
        ObjectiveC.msgSend(
            AUAudioUnit,
            "instantiateWithComponentDescription:options:completionHandler:",
            component_obj,  # AudioComponentDescription
            UInt32(0),       # options
            block            # completion handler
        )
    end

    # Create AudioUnit struct
    au = AudioUnit(
        component_obj,
        au_instance,
        info.name,
        info.manufacturer,
        info.version,
        info.type,
        info.subtype
    )

    return au
end

"""
    initialize(au::AudioUnit) -> Bool

Initialize an AudioUnit for processing. Must be called before using the unit.

For AUv3, this allocates render resources and caches the parameter tree
and render block for later use.

Returns `true` on success, `false` otherwise.
"""
function initialize(au::AudioUnit)
    if au.initialized
        @warn "AudioUnit already initialized"
        return true
    end

    if isnothing(au.instance) || au.instance == C_NULL
        error("AudioUnit instance is null")
    end

    # Allocate render resources
    error_ref = Ref{ObjectiveC.Object}(C_NULL)
    success = ObjectiveC.msgSend(
        au.instance,
        "allocateRenderResourcesAndReturnError:",
        error_ref,
        Bool
    )

    if !success
        err_desc = get_nserror_description(error_ref[])
        @error "Failed to allocate render resources: $err_desc"
        return false
    end

    # Cache parameter tree for performance
    try
        au.parameter_tree = ObjectiveC.msgSend(
            au.instance,
            "parameterTree",
            ObjectiveC.Object
        )
    catch e
        @debug "Failed to cache parameter tree: $e"
        au.parameter_tree = nothing
    end

    # Cache render block for processing
    try
        au.render_block = ObjectiveC.msgSend(
            au.instance,
            "internalRenderBlock",
            ObjectiveC.Object
        )
    catch e
        @debug "Failed to cache render block: $e"
        au.render_block = nothing
    end

    au.allocated_resources = true
    au.initialized = true

    return true
end

"""
    uninitialize(au::AudioUnit) -> Bool

Uninitialize an AudioUnit. Deallocates render resources.

Can be called before reconfiguring the AudioUnit or when done processing.

Returns `true` on success, `false` otherwise.
"""
function uninitialize(au::AudioUnit)
    if !au.initialized
        return true
    end

    if au.allocated_resources
        try
            ObjectiveC.msgSend(au.instance, "deallocateRenderResources")
            au.allocated_resources = false
        catch e
            @error "Failed to deallocate render resources: $e"
            return false
        end
    end

    # Clear cached objects
    au.parameter_tree = nothing
    au.render_block = nothing
    au.initialized = false

    return true
end

"""
    dispose(au::AudioUnit)

Dispose of an AudioUnit instance and free its resources.

This should be called when you're completely done with an AudioUnit.
After calling dispose, the AudioUnit object should not be used.
"""
function dispose(au::AudioUnit)
    if au.initialized
        uninitialize(au)
    end

    # No special cleanup needed for ObjectiveC objects - ARC handles it
    au.parameter_tree = nothing
    au.render_block = nothing
    au.instance = nothing
    au.component = nothing
end

# ============================================================================
# Helper Functions
# ============================================================================

"""
    extract_audiounit_info(component::ObjectiveC.Object) -> Union{AudioUnitInfo, Nothing}

Extract AudioUnitInfo from an AVAudioUnitComponent object.
"""
function extract_audiounit_info(component::ObjectiveC.Object)
    if isnothing(component) || component == C_NULL
        return nothing
    end

    try
        # Get name
        name_obj = ObjectiveC.msgSend(component, "name", ObjectiveC.Object)
        name = nsstring_to_julia(name_obj)

        # Get manufacturer name
        mfr_obj = ObjectiveC.msgSend(component, "manufacturerName", ObjectiveC.Object)
        manufacturer = nsstring_to_julia(mfr_obj)

        # Get version
        version = ObjectiveC.msgSend(component, "version", UInt32)

        # Get component description
        desc_obj = ObjectiveC.msgSend(component, "audioComponentDescription", ObjectiveC.Object)

        # Extract type and subtype from description
        au_type = ObjectiveC.msgSend(desc_obj, "componentType", UInt32)
        subtype = ObjectiveC.msgSend(desc_obj, "componentSubType", UInt32)

        # Convert type to enum
        type_enum = try
            AudioUnitType(au_type)
        catch
            return nothing  # Skip unknown types
        end

        return AudioUnitInfo(name, manufacturer, type_enum, subtype, version)
    catch e
        @debug "Failed to extract AudioUnit info: $e"
        return nothing
    end
end

end  # module core
