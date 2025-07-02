# Data source implementations

# Data source types
struct CSVSource <: DataSource
    path::String
    options::Dict{Symbol, Any}
    
    function CSVSource(path::String, options::Dict{Symbol, Any}=Dict{Symbol, Any}())
        new(path, options)
    end
end

struct JSONSource <: DataSource
    path::String
    key_path::Vector{String}  # Path to data within JSON
    
    function JSONSource(path::String, key_path::Vector{String}=String[])
        new(path, key_path)
    end
end

struct APISource <: DataSource
    url::String
    headers::Dict{String, String}
    transform_function::Union{Nothing, Function}
    
    function APISource(url::String, headers::Dict{String, String}=Dict{String, String}(), 
                      transform_function::Union{Nothing, Function}=nothing)
        new(url, headers, transform_function)
    end
end

struct FunctionSource <: DataSource
    func::Function
    args::Vector{Any}
    
    function FunctionSource(func::Function, args::Vector{Any}=Any[])
        new(func, args)
    end
end

struct OverrideSource <: DataSource
    data::Any
    
    function OverrideSource(data::Any)
        new(data)
    end
end

# Data loading functions
function load_data(source::CSVSource)::DataFrame
    if !isfile(source.path)
        throw(ArgumentError("CSV file not found: $(source.path)"))
    end
    
    try
        return CSV.read(source.path, DataFrame; source.options...)
    catch e
        throw(ArgumentError("Failed to load CSV file $(source.path): $e"))
    end
end

function load_data(source::JSONSource)::Any
    if !isfile(source.path)
        throw(ArgumentError("JSON file not found: $(source.path)"))
    end
    
    try
        json_data = JSON3.read(read(source.path, String))
        
        # Navigate to specified key path
        result = json_data
        for key in source.key_path
            if haskey(result, key)
                result = result[key]
            else
                throw(ArgumentError("Key path not found in JSON: $(join(source.key_path, '.'))"))
            end
        end
        
        return result
    catch e
        throw(ArgumentError("Failed to load JSON file $(source.path): $e"))
    end
end

function load_data(source::APISource)::Any
    try
        response = HTTP.get(source.url; headers=source.headers)
        
        if response.status != 200
            throw(ArgumentError("API request failed with status $(response.status)"))
        end
        
        data = JSON3.read(String(response.body))
        
        # Apply transformation if provided
        if source.transform_function !== nothing
            data = source.transform_function(data)
        end
        
        return data
    catch e
        throw(ArgumentError("Failed to load data from API $(source.url): $e"))
    end
end

function load_data(source::FunctionSource)::Any
    try
        return source.func(source.args...)
    catch e
        throw(ArgumentError("Failed to load data from function: $e"))
    end
end

function load_data(source::OverrideSource)::Any
    return source.data
end

# Helper functions for data conversion
function to_dataframe(data::Vector{Dict{String, Any}}, schema::Vector{Symbol})::DataFrame
    df = DataFrame()
    for col in schema
        df[!, col] = [get(row, String(col), missing) for row in data]
    end
    return df
end

function to_dataframe(data::Vector{Vector{Any}}, schema::Vector{Symbol})::DataFrame
    if length(schema) != length(data[1])
        throw(ArgumentError("Schema length ($(length(schema))) doesn't match data columns ($(length(data[1])))"))
    end
    
    df = DataFrame()
    for (i, col) in enumerate(schema)
        df[!, col] = [row[i] for row in data]
    end
    return df
end

# Source creation helpers
function create_source(source_config::Dict{String, Any})::DataSource
    source_type = get(source_config, "type", "")
    
    if source_type == "csv"
        path = get(source_config, "path", "")
        options = get(source_config, "options", Dict())
        return CSVSource(path, Dict{Symbol, Any}(Symbol(k) => v for (k, v) in options))
        
    elseif source_type == "json"
        path = get(source_config, "path", "")
        key_path = get(source_config, "key_path", String[])
        return JSONSource(path, key_path)
        
    elseif source_type == "api"
        url = get(source_config, "url", "")
        headers = get(source_config, "headers", Dict{String, String}())
        return APISource(url, headers)
        
    elseif source_type == "override"
        data = get(source_config, "data", nothing)
        return OverrideSource(data)
        
    else
        throw(ArgumentError("Unknown source type: $source_type"))
    end
end