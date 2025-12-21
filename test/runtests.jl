using AudioUnits
using Test

@testset "AudioUnits.jl" begin
    @testset "AudioUnit Discovery" begin
        # Test finding all AudioUnits
        all_units = find_audiounits()
        @test length(all_units) > 0
        @test all_units[1] isa AudioUnitInfo
        @test all_units[1].name isa String
        @test all_units[1].manufacturer isa String
        @test all_units[1].type isa AudioUnitType
        @test all_units[1].subtype isa UInt32
        @test all_units[1].version isa UInt32

        # Test filtering by type
        effects = find_audiounits(kAudioUnitType_Effect)
        @test all(u -> u.type == kAudioUnitType_Effect, effects)

        music_devices = find_audiounits(kAudioUnitType_MusicDevice)
        @test all(u -> u.type == kAudioUnitType_MusicDevice, music_devices)
    end

    @testset "AudioUnit Loading and Lifecycle" begin
        # Find an effect to test with
        effects = find_audiounits(kAudioUnitType_Effect)
        if !isempty(effects)
            effect = effects[1]

            # Test loading by type/subtype
            au = load_audiounit(effect.type, effect.subtype)
            @test au.name == effect.name
            @test au.au_type == effect.type
            @test !au.initialized

            # Test initialization
            @test initialize_audiounit(au) == true
            @test au.initialized == true

            # Test double initialization (should warn but succeed)
            @test initialize_audiounit(au) == true

            # Test uninitialization
            @test uninitialize_audiounit(au) == true
            @test au.initialized == false

            # Test disposal
            dispose_audiounit(au)
            @test au.instance == C_NULL

            # Test loading by name
            au2 = load_audiounit(effect.name)
            @test au2.name == effect.name
            dispose_audiounit(au2)
        else
            @warn "No effect units found for testing"
        end
    end

    @testset "Parameter Management" begin
        effects = find_audiounits(kAudioUnitType_Effect)
        if !isempty(effects)
            au = load_audiounit(effects[1].type, effects[1].subtype)
            initialize_audiounit(au)

            # Test parameter retrieval
            params = get_parameters(au)
            @test params isa Vector{AudioUnitParameter}

            # Test parameter info
            if !isempty(params)
                param = params[1]
                @test param.info.name isa String
                @test param.info.min_value <= param.info.max_value
                @test param.info.min_value <= param.info.default_value <= param.info.max_value

                # Test getting parameter value
                value = get_parameter_value(au, param.id)
                @test value isa Float32

                # Test setting parameter value
                test_val = (param.info.min_value + param.info.max_value) / 2
                @test set_parameter_value(au, param.id, test_val) == true

                new_value = get_parameter_value(au, param.id)
                @test new_value ≈ test_val atol=0.01
            end

            uninitialize_audiounit(au)
            dispose_audiounit(au)
        end
    end

    @testset "Capability Detection" begin
        # Test effects
        effects = find_audiounits(kAudioUnitType_Effect)
        if !isempty(effects)
            au = load_audiounit(effects[1].type, effects[1].subtype)
            @test supports_effects(au) == true
            @test supports_midi(au) == false

            configs = get_channel_capabilities(au)
            @test configs isa Vector{ChannelConfiguration}
            @test !isempty(configs)
            @test configs[1].input_channels isa Int16
            @test configs[1].output_channels isa Int16

            dispose_audiounit(au)
        end

        # Test music devices
        instruments = find_audiounits(kAudioUnitType_MusicDevice)
        if !isempty(instruments)
            au = load_audiounit(instruments[1].type, instruments[1].subtype)
            @test supports_midi(au) == true

            dispose_audiounit(au)
        end
    end

    @testset "Documentation and Info" begin
        all_units = find_audiounits()
        if !isempty(all_units)
            au = load_audiounit(all_units[1].type, all_units[1].subtype)

            # Test get_info
            info = get_info(au)
            @test info isa AudioUnitSummary
            @test info.name isa String
            @test info.manufacturer isa String
            @test info.version isa Tuple{UInt16, UInt8, UInt8}
            @test info.supports_effects isa Bool
            @test info.supports_midi isa Bool
            @test info.parameter_count isa Int

            # Test documentation generation
            doc = get_documentation(au)
            @test doc isa String
            @test length(doc) > 0
            @test occursin(au.name, doc)

            # Test list generation
            list = list_all_audiounits()
            @test list isa String
            @test length(list) > 0

            dispose_audiounit(au)
        end
    end

    @testset "Stream Format and Latency" begin
        effects = find_audiounits(kAudioUnitType_Effect)
        if !isempty(effects)
            au = load_audiounit(effects[1].type, effects[1].subtype)
            initialize_audiounit(au)

            # Test stream format
            format = get_stream_format(au)
            @test format isa StreamFormat
            @test format.sample_rate > 0
            @test format.channels_per_frame > 0

            # Test latency (may be 0)
            latency = get_latency(au)
            @test latency >= 0

            # Test tail time (may be 0)
            tail = get_tail_time(au)
            @test tail >= 0

            uninitialize_audiounit(au)
            dispose_audiounit(au)
        end
    end

    @testset "Bypass Mode" begin
        effects = find_audiounits(kAudioUnitType_Effect)
        if !isempty(effects)
            au = load_audiounit(effects[1].type, effects[1].subtype)
            initialize_audiounit(au)

            # Test bypass capability check
            can_bypass_result = can_bypass(au)
            @test can_bypass_result isa Bool

            # If bypass is supported, test setting it
            if can_bypass_result
                @test set_bypass(au, true) == true
                @test set_bypass(au, false) == true
            end

            uninitialize_audiounit(au)
            dispose_audiounit(au)
        end
    end

    @testset "Display Methods" begin
        all_units = find_audiounits()
        if !isempty(all_units)
            au = load_audiounit(all_units[1].type, all_units[1].subtype)

            # Test compact display
            io = IOBuffer()
            show(io, au)
            output = String(take!(io))
            @test occursin("AudioUnit", output)
            @test occursin(au.name, output)

            # Test plain text display
            io = IOBuffer()
            show(io, MIME("text/plain"), au)
            output = String(take!(io))
            @test occursin(au.name, output)
            @test occursin("Manufacturer", output)
            @test occursin("Capabilities", output)

            # Test HTML display
            io = IOBuffer()
            show(io, MIME("text/html"), au)
            output = String(take!(io))
            @test occursin("<div", output)
            @test occursin(au.name, output)
            @test occursin("AudioUnit", output)

            # Test parameter display
            params = get_parameters(au)
            if !isempty(params)
                param = params[1]

                # Compact display
                io = IOBuffer()
                show(io, param)
                output = String(take!(io))
                @test occursin("AudioUnitParameter", output)

                # Plain text display
                io = IOBuffer()
                show(io, MIME("text/plain"), param)
                output = String(take!(io))
                @test occursin(param.info.name, output)
                @test occursin("Range", output)

                # HTML display
                io = IOBuffer()
                show(io, MIME("text/html"), param)
                output = String(take!(io))
                @test occursin("<div", output)
                @test occursin(param.info.name, output)

                # Test parameter info display
                info = param.info

                # Compact display
                io = IOBuffer()
                show(io, info)
                output = String(take!(io))
                @test occursin("AudioUnitParameterInfo", output)

                # Plain text display
                io = IOBuffer()
                show(io, MIME("text/plain"), info)
                output = String(take!(io))
                @test occursin(info.name, output)

                # HTML display
                io = IOBuffer()
                show(io, MIME("text/html"), info)
                output = String(take!(io))
                @test occursin("<div", output)
                @test occursin(info.name, output)
            end

            dispose_audiounit(au)
        end
    end
end
