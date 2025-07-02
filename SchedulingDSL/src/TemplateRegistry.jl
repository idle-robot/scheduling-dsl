# Template registry for model builders, constraints, and objectives

# Global registries
const MODEL_TEMPLATES = Dict{String, Function}()
const CONSTRAINT_FUNCTIONS = Dict{String, Function}()
const OBJECTIVE_FUNCTIONS = Dict{String, Function}()

# Template registration functions
function register_template!(name::String, template_func::Function)
    MODEL_TEMPLATES[name] = template_func
    @info "Registered template: $name"
end

function get_template(name::String)::Function
    if !haskey(MODEL_TEMPLATES, name)
        throw(ArgumentError("Template '$name' not found. Available templates: $(collect(keys(MODEL_TEMPLATES)))"))
    end
    return MODEL_TEMPLATES[name]
end

function list_templates()::Vector{String}
    return collect(keys(MODEL_TEMPLATES))
end

# Constraint registration functions
function register_constraint!(name::String, constraint_func::Function)
    CONSTRAINT_FUNCTIONS[name] = constraint_func
    @info "Registered constraint: $name"
end

function get_constraint(name::String)::Function
    if !haskey(CONSTRAINT_FUNCTIONS, name)
        throw(ArgumentError("Constraint '$name' not found. Available constraints: $(collect(keys(CONSTRAINT_FUNCTIONS)))"))
    end
    return CONSTRAINT_FUNCTIONS[name]
end

function list_constraints()::Vector{String}
    return collect(keys(CONSTRAINT_FUNCTIONS))
end

# Objective registration functions
function register_objective!(name::String, objective_func::Function)
    OBJECTIVE_FUNCTIONS[name] = objective_func
    @info "Registered objective: $name"
end

function get_objective(name::String)::Function
    if !haskey(OBJECTIVE_FUNCTIONS, name)
        throw(ArgumentError("Objective '$name' not found. Available objectives: $(collect(keys(OBJECTIVE_FUNCTIONS)))"))
    end
    return OBJECTIVE_FUNCTIONS[name]
end

function list_objectives()::Vector{String}
    return collect(keys(OBJECTIVE_FUNCTIONS))
end

# Model building function
function build_model(spec::ModelSpec)::Model
    # Get the template function
    template_func = get_template(spec.template)
    
    # Load all parameter data
    loaded_spec = load_spec_data(spec)
    
    # Build the base model
    model = template_func(loaded_spec)
    
    # Apply constraint overrides
    if haskey(loaded_spec.overrides, :constraints)
        for override in loaded_spec.overrides[:constraints]
            constraint_func = get_constraint(override.function_name)
            constraint_func(model, loaded_spec, override.args)
        end
    end
    
    # Apply objective overrides
    if haskey(loaded_spec.overrides, :objective)
        objective_overrides = loaded_spec.overrides[:objective]
        if !isempty(objective_overrides)
            # Use the first objective override
            override = objective_overrides[1]
            objective_func = get_objective(override.function_name)
            objective_func(model, loaded_spec, override.args)
        end
    end
    
    return model
end

# Load all parameter data from sources
function load_spec_data(spec::ModelSpec)::ModelSpec
    loaded_parameters = Dict{Symbol, ParameterSpec}()
    
    for (name, param) in spec.parameters
        if param isa TableParameter
            data = load_data(param.source)
            loaded_parameters[name] = TableParameter(param.schema, param.source, data)
        elseif param isa DictParameter
            data = load_data(param.source)
            # Convert to Dict if needed
            if data isa DataFrame
                # Assume first column is key, second is value
                dict_data = Dict(row[1] => row[2] for row in eachrow(data))
            else
                dict_data = data
            end
            loaded_parameters[name] = DictParameter(param.key, param.source, dict_data)
        else
            loaded_parameters[name] = param
        end
    end
    
    return ModelSpec(spec.template, spec.indexes, loaded_parameters, spec.options, spec.overrides)
end

# Model solving function
function solve_model(model::Model)::Dict{String, Any}
    optimize!(model)
    
    status = termination_status(model)
    
    result = Dict{String, Any}(
        "status" => string(status),
        "objective_value" => nothing,
        "solve_time" => solve_time(model),
        "variables" => Dict{String, Any}()
    )
    
    if status == MOI.OPTIMAL
        result["objective_value"] = objective_value(model)
        
        # Extract variable values
        for (name, var) in object_dictionary(model)
            if var isa VariableRef
                result["variables"][String(name)] = value(var)
            elseif var isa Array{VariableRef}
                # Handle arrays of variables
                result["variables"][String(name)] = value.(var)
            end
        end
    end
    
    return result
end

# UI specification generation for natural language interface
function create_ui_spec(spec::ModelSpec, query::String="")::Dict{String, Any}
    ui_spec = Dict{String, Any}(
        "visualization_type" => infer_visualization_type(spec),
        "controls" => create_controls(spec),
        "filters" => create_filters(spec),
        "metrics" => create_metrics(spec),
        "query_context" => query
    )
    
    return ui_spec
end

function infer_visualization_type(spec::ModelSpec)::String
    if spec.template == "work_scheduling"
        return "schedule_gantt"
    elseif contains(spec.template, "assignment")
        return "assignment_matrix"
    elseif contains(spec.template, "routing")
        return "route_map"
    else
        return "generic_table"
    end
end

function create_controls(spec::ModelSpec)::Vector{Dict{String, Any}}
    controls = Dict{String, Any}[]
    
    # Create controls for indexes
    for (name, index) in spec.indexes
        if index isa DateRangeIndex
            push!(controls, Dict(
                "type" => "date_range",
                "label" => titlecase(replace(string(name), "_" => " ")),
                "default" => [string(index.start), string(index.end_date)],
                "maps_to" => "indexes.$(name)"
            ))
        elseif index isa ListIndex
            push!(controls, Dict(
                "type" => "multiselect",
                "label" => titlecase(replace(string(name), "_" => " ")),
                "options" => index.values,
                "default" => index.values,
                "maps_to" => "indexes.$(name)"
            ))
        end
    end
    
    # Create controls for parameters that might be adjustable
    for (name, param) in spec.parameters
        param_name_str = string(name)
        if contains(param_name_str, "cost") || contains(param_name_str, "weight") || contains(param_name_str, "multiplier")
            push!(controls, Dict(
                "type" => "slider",
                "label" => titlecase(replace(param_name_str, "_" => " ")) * " Multiplier",
                "min" => 0.1,
                "max" => 3.0,
                "default" => 1.0,
                "step" => 0.1,
                "maps_to" => "parameters.$(name).multiplier"
            ))
        elseif contains(param_name_str, "demand") || contains(param_name_str, "capacity")
            push!(controls, Dict(
                "type" => "slider",
                "label" => titlecase(replace(param_name_str, "_" => " ")) * " Scale",
                "min" => 0.5,
                "max" => 2.0,
                "default" => 1.0,
                "step" => 0.1,
                "maps_to" => "parameters.$(name).scale"
            ))
        end
    end
    
    return controls
end

function create_filters(spec::ModelSpec)::Vector{String}
    filters = String[]
    
    # Add common filters based on indexes
    for (name, index) in spec.indexes
        if index isa ListIndex && length(index.values) > 1
            push!(filters, string(name))
        end
    end
    
    return filters
end

function create_metrics(spec::ModelSpec)::Vector{String}
    metrics = ["objective_value", "solve_time"]
    
    # Add template-specific metrics
    if spec.template == "work_scheduling"
        append!(metrics, ["total_cost", "coverage_rate", "staff_utilization"])
    elseif contains(spec.template, "routing")
        append!(metrics, ["total_distance", "vehicle_utilization"])
    end
    
    return metrics
end