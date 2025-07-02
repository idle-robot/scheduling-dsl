using Test
using SchedulingDSL

@testset "SchedulingDSL.jl" begin
    @testset "ModelSpec Tests" begin
        # Test DateRangeIndex
        start_date = Date(2025, 7, 1)
        end_date = Date(2025, 7, 7)
        date_index = DateRangeIndex(start_date, end_date)
        @test date_index.start == start_date
        @test date_index.end == end_date
        
        # Test ListIndex
        candidates = ["Alice", "Bob", "Carol"]
        list_index = ListIndex(candidates)
        @test list_index.values == candidates
        
        # Test ModelSpec creation
        spec = ModelSpec("work_scheduling")
        @test spec.template == "work_scheduling"
        @test isempty(spec.indexes)
        @test isempty(spec.parameters)
        @test isempty(spec.options)
        @test isempty(spec.overrides)
    end
    
    @testset "Data Source Tests" begin
        # Test CSVSource
        csv_source = CSVSource("test.csv")
        @test csv_source.path == "test.csv"
        @test isempty(csv_source.options)
        
        # Test JSONSource
        json_source = JSONSource("test.json", ["data"])
        @test json_source.path == "test.json"
        @test json_source.key_path == ["data"]
        
        # Test OverrideSource
        test_data = [1, 2, 3]
        override_source = OverrideSource(test_data)
        @test load_data(override_source) == test_data
    end
    
    @testset "Config Parser Tests" begin
        # Test simple config dict parsing
        config_dict = Dict(
            "template" => "work_scheduling",
            "indexes" => Dict(
                "days" => Dict(
                    "type" => "date_range",
                    "start" => "2025-07-01",
                    "end" => "2025-07-07"
                ),
                "candidates" => Dict(
                    "type" => "list",
                    "values" => ["Alice", "Bob"]
                )
            ),
            "options" => Dict(
                "max_daily_assignments" => 2
            )
        )
        
        spec = parse_config_dict(config_dict)
        @test spec.template == "work_scheduling"
        @test haskey(spec.indexes, :days)
        @test haskey(spec.indexes, :candidates)
        @test spec.options[:max_daily_assignments] == 2
    end
    
    @testset "Template Registry Tests" begin
        # Test template registration
        function dummy_template(spec::ModelSpec)
            return "dummy_model"
        end
        
        register_template!("dummy", dummy_template)
        @test "dummy" in list_templates()
        
        retrieved_template = get_template("dummy")
        @test retrieved_template == dummy_template
        
        # Test constraint registration
        function dummy_constraint(model, spec, args)
            return "dummy_constraint"
        end
        
        register_constraint!("dummy_constraint", dummy_constraint)
        @test "dummy_constraint" in list_constraints()
    end
    
    @testset "Config Patching Tests" begin
        # Create a simple spec
        spec = ModelSpec("work_scheduling")
        
        # Test config patch
        patch = ConfigPatch("merge", ["options", "max_daily_assignments"], 3)
        updated_spec = apply_config_patch(spec, patch)
        
        @test updated_spec.options[:max_daily_assignments] == 3
        @test spec.options != updated_spec.options  # Original unchanged
    end
end