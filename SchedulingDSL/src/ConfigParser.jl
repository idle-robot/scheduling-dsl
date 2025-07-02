# YAML/JSON config parsing and validation

function parse_config(config_path::String)::ModelSpec
    if !isfile(config_path)
        throw(ArgumentError("Config file not found: $config_path"))
    end
    
    try
        # Determine file type and parse
        if endswith(config_path, ".yaml") || endswith(config_path, ".yml")
            config_dict = YAML.load_file(config_path)
        elseif endswith(config_path, ".json")
            config_dict = JSON3.read(read(config_path, String))
        else
            throw(ArgumentError("Unsupported config file type. Use .yaml, .yml, or .json"))
        end
        
        return parse_config_dict(config_dict)
    catch e
        throw(ArgumentError("Failed to parse config file $config_path: $e"))
    end
end

function parse_config_dict(config_dict::Dict)::ModelSpec
    # Extract template
    template = get(config_dict, "template", "")
    if isempty(template)
        throw(ArgumentError("Template must be specified"))
    end
    
    # Parse indexes
    indexes = Dict{Symbol, IndexSpec}()
    if haskey(config_dict, "indexes")
        for (name, index_config) in config_dict["indexes"]
            indexes[Symbol(name)] = parse_index(index_config)
        end
    end
    
    # Parse parameters
    parameters = Dict{Symbol, ParameterSpec}()
    if haskey(config_dict, "parameters")
        for (name, param_config) in config_dict["parameters"]
            parameters[Symbol(name)] = parse_parameter(param_config)
        end
    end
    
    # Parse options
    options = Dict{Symbol, Any}()
    if haskey(config_dict, "options")
        for (key, value) in config_dict["options"]
            options[Symbol(key)] = value
        end
    end
    
    # Parse overrides
    overrides = Dict{Symbol, Vector{Override}}()
    if haskey(config_dict, "overrides")
        for (section, override_list) in config_dict["overrides"]
            section_symbol = Symbol(section)
            overrides[section_symbol] = Override[]
            
            for override_config in override_list
                name = get(override_config, "name", "")
                func_name = get(override_config, "function", "")
                args = get(override_config, "args", Dict())
                
                push!(overrides[section_symbol], 
                      Override(name, func_name, Dict{Symbol, Any}(Symbol(k) => v for (k, v) in args)))
            end
        end
    end
    
    spec = ModelSpec(template, indexes, parameters, options, overrides)
    validate_spec(spec)
    return spec
end

function parse_index(index_config::Dict)::IndexSpec
    index_type = get(index_config, "type", "")
    
    if index_type == "date_range"
        start_str = get(index_config, "start", "")
        end_str = get(index_config, "end", "")
        
        if isempty(start_str) || isempty(end_str)
            throw(ArgumentError("Date range index requires start and end dates"))
        end
        
        start_date = Date(start_str)
        end_date = Date(end_str)
        
        return DateRangeIndex(start_date, end_date)
        
    elseif index_type == "list"
        values = get(index_config, "values", String[])
        if isempty(values)
            throw(ArgumentError("List index requires values"))
        end
        
        return ListIndex(values)
        
    else
        throw(ArgumentError("Unknown index type: $index_type"))
    end
end

function parse_parameter(param_config::Dict)::ParameterSpec
    param_type = get(param_config, "type", "")
    
    if param_type == "table"
        schema_strings = get(param_config, "schema", String[])
        schema = [Symbol(s) for s in schema_strings]
        
        if isempty(schema)
            throw(ArgumentError("Table parameter requires schema"))
        end
        
        source_config = get(param_config, "source", Dict())
        source = create_source(source_config)
        
        return TableParameter(schema, source)
        
    elseif param_type == "dict"
        key_string = get(param_config, "key", "")
        if isempty(key_string)
            throw(ArgumentError("Dict parameter requires key"))
        end
        
        key = Symbol(key_string)
        source_config = get(param_config, "source", Dict())
        source = create_source(source_config)
        
        return DictParameter(key, source)
        
    elseif param_type == "scalar"
        value = get(param_config, "value", nothing)
        value_type = get(param_config, "value_type", "Any")
        
        # Convert type string to actual type
        julia_type = if value_type == "Int"
            Int
        elseif value_type == "Float64"
            Float64
        elseif value_type == "String"
            String
        elseif value_type == "Bool"
            Bool
        else
            Any
        end
        
        return ScalarParameter(value, julia_type)
        
    else
        throw(ArgumentError("Unknown parameter type: $param_type"))
    end
end

# Config validation functions
function validate_config_schema(config_dict::Dict)::Bool
    required_fields = ["template"]
    
    for field in required_fields
        if !haskey(config_dict, field)
            throw(ArgumentError("Required field '$field' missing from config"))
        end
    end
    
    # Validate optional sections
    valid_sections = ["template", "indexes", "parameters", "options", "overrides"]
    for key in keys(config_dict)
        if !(key in valid_sections)
            @warn "Unknown config section: $key"
        end
    end
    
    return true
end

# Helper function to convert config to dict for serialization
function spec_to_dict(spec::ModelSpec)::Dict{String, Any}
    result = Dict{String, Any}()
    result["template"] = spec.template
    
    # Convert indexes
    if !isempty(spec.indexes)
        result["indexes"] = Dict{String, Any}()
        for (name, index) in spec.indexes
            result["indexes"][String(name)] = index_to_dict(index)
        end
    end
    
    # Convert parameters
    if !isempty(spec.parameters)
        result["parameters"] = Dict{String, Any}()
        for (name, param) in spec.parameters
            result["parameters"][String(name)] = parameter_to_dict(param)
        end
    end
    
    # Convert options
    if !isempty(spec.options)
        result["options"] = Dict{String, Any}()
        for (key, value) in spec.options
            result["options"][String(key)] = value
        end
    end
    
    # Convert overrides
    if !isempty(spec.overrides)
        result["overrides"] = Dict{String, Any}()
        for (section, override_list) in spec.overrides
            result["overrides"][String(section)] = [
                Dict("name" => o.name, "function" => o.function_name, "args" => o.args)
                for o in override_list
            ]
        end
    end
    
    return result
end

function index_to_dict(index::IndexSpec)::Dict{String, Any}
    if index isa DateRangeIndex
        return Dict(
            "type" => "date_range",
            "start" => string(index.start),
            "end" => string(index.end)
        )
    elseif index isa ListIndex
        return Dict(
            "type" => "list",
            "values" => index.values
        )
    else
        throw(ArgumentError("Unknown index type: $(typeof(index))"))
    end
end

function parameter_to_dict(param::ParameterSpec)::Dict{String, Any}
    if param isa TableParameter
        return Dict(
            "type" => "table",
            "schema" => [String(s) for s in param.schema],
            "source" => source_to_dict(param.source)
        )
    elseif param isa DictParameter
        return Dict(
            "type" => "dict",
            "key" => String(param.key),
            "source" => source_to_dict(param.source)
        )
    elseif param isa ScalarParameter
        return Dict(
            "type" => "scalar",
            "value" => param.value,
            "value_type" => string(param.type)
        )
    else
        throw(ArgumentError("Unknown parameter type: $(typeof(param))"))
    end
end

function source_to_dict(source::DataSource)::Dict{String, Any}
    if source isa CSVSource
        return Dict(
            "type" => "csv",
            "path" => source.path,
            "options" => source.options
        )
    elseif source isa JSONSource
        return Dict(
            "type" => "json",
            "path" => source.path,
            "key_path" => source.key_path
        )
    elseif source isa APISource
        return Dict(
            "type" => "api",
            "url" => source.url,
            "headers" => source.headers
        )
    elseif source isa OverrideSource
        return Dict(
            "type" => "override",
            "data" => source.data
        )
    else
        throw(ArgumentError("Unknown source type: $(typeof(source))"))
    end
end