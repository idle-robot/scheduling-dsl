# Type system for strongly typed model specifications

using Dates
using DataFrames

abstract type IndexSpec end
abstract type ParameterSpec end
abstract type DataSource end

# Index specifications
struct DateRangeIndex <: IndexSpec
    start::Date
    end_date::Date
    
    function DateRangeIndex(start::Date, end_date::Date)
        start <= end_date || throw(ArgumentError("Start date must be <= end date"))
        new(start, end_date)
    end
end

struct ListIndex <: IndexSpec
    values::Vector{String}
    
    function ListIndex(values::Vector{String})
        length(values) > 0 || throw(ArgumentError("Index values cannot be empty"))
        new(values)
    end
end

# Parameter specifications
struct TableParameter <: ParameterSpec
    schema::Vector{Symbol}
    source::DataSource
    data::Union{Nothing, DataFrame}
    
    function TableParameter(schema::Vector{Symbol}, source::DataSource, data=nothing)
        length(schema) > 0 || throw(ArgumentError("Schema cannot be empty"))
        new(schema, source, data)
    end
end

struct DictParameter <: ParameterSpec
    key::Symbol
    source::DataSource
    data::Union{Nothing, Dict}
    
    function DictParameter(key::Symbol, source::DataSource, data=nothing)
        new(key, source, data)
    end
end

struct ScalarParameter <: ParameterSpec
    value::Any
    type::Type
    
    function ScalarParameter(value::Any, type::Type=typeof(value))
        new(value, type)
    end
end

# Override specifications
struct Override
    name::String
    function_name::String
    args::Dict{Symbol, Any}
    
    function Override(name::String, function_name::String, args=Dict{Symbol, Any}())
        new(name, function_name, args)
    end
end

# Main model specification
struct ModelSpec
    template::String
    indexes::Dict{Symbol, IndexSpec}
    parameters::Dict{Symbol, ParameterSpec}
    options::Dict{Symbol, Any}
    overrides::Dict{Symbol, Vector{Override}}
    
    function ModelSpec(template::String, 
                      indexes::Dict{Symbol, IndexSpec}=Dict{Symbol, IndexSpec}(),
                      parameters::Dict{Symbol, ParameterSpec}=Dict{Symbol, ParameterSpec}(),
                      options::Dict{Symbol, Any}=Dict{Symbol, Any}(),
                      overrides::Dict{Symbol, Vector{Override}}=Dict{Symbol, Vector{Override}}())
        new(template, indexes, parameters, options, overrides)
    end
end

# Utility functions for ModelSpec
function get_index_values(spec::ModelSpec, index_name::Symbol)
    index = get(spec.indexes, index_name, nothing)
    index === nothing && throw(ArgumentError("Index $index_name not found"))
    
    if index isa DateRangeIndex
        return collect(index.start:Day(1):index.end_date)
    elseif index isa ListIndex
        return index.values
    else
        throw(ArgumentError("Unknown index type: $(typeof(index))"))
    end
end

function get_parameter_data(spec::ModelSpec, param_name::Symbol)
    param = get(spec.parameters, param_name, nothing)
    param === nothing && throw(ArgumentError("Parameter $param_name not found"))
    
    if param.data !== nothing
        return param.data
    else
        # Load data from source if not already loaded
        return load_data(param.source)
    end
end

function validate_spec(spec::ModelSpec)::Bool
    # Validate template exists
    length(spec.template) > 0 || throw(ArgumentError("Template name cannot be empty"))
    
    # Validate indexes
    for (name, index) in spec.indexes
        if index isa DateRangeIndex
            # Already validated in constructor
        elseif index isa ListIndex
            # Already validated in constructor
        else
            throw(ArgumentError("Unknown index type for $name: $(typeof(index))"))
        end
    end
    
    # Validate parameters have valid schemas
    for (name, param) in spec.parameters
        if param isa TableParameter
            length(param.schema) > 0 || throw(ArgumentError("Table parameter $name has empty schema"))
        end
    end
    
    return true
end

# Config patching for dynamic updates
struct ConfigPatch
    operation::String  # "merge", "replace", "delete"
    path::Vector{String}
    value::Any
end

function apply_config_patch(spec::ModelSpec, patch::ConfigPatch)::ModelSpec
    # Deep copy the spec
    new_spec = deepcopy(spec)
    
    if patch.operation == "merge" && length(patch.path) >= 2
        section = patch.path[1]
        key = Symbol(patch.path[2])
        
        if section == "parameters"
            if haskey(new_spec.parameters, key)
                # Update parameter data
                param = new_spec.parameters[key]
                if param isa TableParameter && patch.value isa Vector
                    # Convert to DataFrame
                    df = DataFrame([col => [row[i] for row in patch.value] 
                                  for (i, col) in enumerate(param.schema)])
                    new_spec.parameters[key] = TableParameter(param.schema, param.source, df)
                elseif param isa DictParameter && patch.value isa Dict
                    new_spec.parameters[key] = DictParameter(param.key, param.source, patch.value)
                end
            end
        elseif section == "options"
            new_spec.options[key] = patch.value
        end
    end
    
    return new_spec
end