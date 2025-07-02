module SchedulingDSL

using JuMP
using HiGHS
using DataFrames
using CSV
using JSON3
using YAML
using HTTP
using Dates

# Core modules
include("ModelSpec.jl")
include("ConfigParser.jl")
include("Sources.jl")
include("TemplateRegistry.jl")
include("Templates/WorkScheduling.jl")
include("API.jl")

# Export main functions and types
export ModelSpec, IndexSpec, ParameterSpec, DataSource
export DateRangeIndex, ListIndex, TableParameter, DictParameter
export CSVSource, JSONSource, APISource, FunctionSource
export parse_config, parse_config_dict, load_data, build_model, solve_model
export register_template!, get_template, register_constraint!, register_objective!
export apply_config_patch, create_ui_spec, start_api_server

end # module SchedulingDSL