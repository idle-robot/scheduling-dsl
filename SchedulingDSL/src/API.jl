# HTTP API backend for the optimization service

using HTTP
using JSON3

# Global state for managing models
const ACTIVE_MODELS = Dict{String, Dict{String, Any}}()
const MODEL_COUNTER = Ref(0)

# API endpoints
function start_api_server(port::Int=8080)
    @info "Starting SchedulingDSL API server on port $port"
    
    # Define routes
    router = HTTP.Router()
    
    # CORS middleware
    function cors_middleware(handler)
        return function(req::HTTP.Request)
            # Handle preflight requests
            if req.method == "OPTIONS"
                return HTTP.Response(200, [
                    "Access-Control-Allow-Origin" => "*",
                    "Access-Control-Allow-Methods" => "GET, POST, PUT, DELETE, PATCH, OPTIONS",
                    "Access-Control-Allow-Headers" => "Content-Type, Authorization"
                ])
            end
            
            # Handle actual requests
            response = handler(req)
            HTTP.setheader(response, "Access-Control-Allow-Origin" => "*")
            HTTP.setheader(response, "Access-Control-Allow-Methods" => "GET, POST, PUT, DELETE, PATCH, OPTIONS")
            HTTP.setheader(response, "Access-Control-Allow-Headers" => "Content-Type, Authorization")
            return response
        end
    end
    
    # Route definitions
    HTTP.register!(router, "GET", "/", health_check)
    HTTP.register!(router, "POST", "/models", create_model)
    HTTP.register!(router, "GET", "/models", list_models)
    HTTP.register!(router, "GET", "/models/*", get_model)
    HTTP.register!(router, "PATCH", "/models/*/config", update_model_config)
    HTTP.register!(router, "POST", "/models/*/solve", solve_model_endpoint)
    HTTP.register!(router, "GET", "/models/*/solution", get_solution)
    HTTP.register!(router, "DELETE", "/models/*", delete_model)
    HTTP.register!(router, "POST", "/models/*/ui-spec", create_ui_spec_endpoint)
    
    # Start server with CORS middleware
    HTTP.serve(cors_middleware(router), port)
end

# Endpoint implementations
function health_check(req::HTTP.Request)
    return HTTP.Response(200, [], JSON3.write(Dict(
        "status" => "healthy",
        "service" => "SchedulingDSL API",
        "active_models" => length(ACTIVE_MODELS)
    )))
end

function create_model(req::HTTP.Request)
    try
        # Parse request body
        body = String(req.body)
        config_dict = JSON3.read(body)
        
        # Parse config into ModelSpec
        spec = parse_config_dict(config_dict)
        
        # Generate unique model ID
        MODEL_COUNTER[] += 1
        model_id = "model_$(MODEL_COUNTER[])"
        
        # Store model information
        ACTIVE_MODELS[model_id] = Dict(
            "id" => model_id,
            "spec" => spec,
            "model" => nothing,
            "solution" => nothing,
            "created_at" => now(),
            "status" => "created"
        )
        
        response_data = Dict(
            "model_id" => model_id,
            "status" => "created",
            "template" => spec.template
        )
        
        return HTTP.Response(201, [], JSON3.write(response_data))
        
    catch e
        error_response = Dict(
            "error" => "Failed to create model",
            "message" => string(e)
        )
        return HTTP.Response(400, [], JSON3.write(error_response))
    end
end

function list_models(req::HTTP.Request)
    models_info = [
        Dict(
            "id" => model_id,
            "template" => model_data["spec"].template,
            "status" => model_data["status"],
            "created_at" => model_data["created_at"]
        )
        for (model_id, model_data) in ACTIVE_MODELS
    ]
    
    return HTTP.Response(200, [], JSON3.write(Dict("models" => models_info)))
end

function get_model(req::HTTP.Request)
    model_id = extract_model_id(req.target)
    
    if !haskey(ACTIVE_MODELS, model_id)
        return HTTP.Response(404, [], JSON3.write(Dict("error" => "Model not found")))
    end
    
    model_data = ACTIVE_MODELS[model_id]
    
    # Convert spec to dict for JSON serialization
    spec_dict = spec_to_dict(model_data["spec"])
    
    response_data = Dict(
        "id" => model_id,
        "spec" => spec_dict,
        "status" => model_data["status"],
        "created_at" => model_data["created_at"]
    )
    
    return HTTP.Response(200, [], JSON3.write(response_data))
end

function update_model_config(req::HTTP.Request)
    model_id = extract_model_id(req.target)
    
    if !haskey(ACTIVE_MODELS, model_id)
        return HTTP.Response(404, [], JSON3.write(Dict("error" => "Model not found")))
    end
    
    try
        # Parse patch request
        body = String(req.body)
        patch_data = JSON3.read(body)
        
        # Apply patch to model spec
        current_spec = ACTIVE_MODELS[model_id]["spec"]
        
        if haskey(patch_data, "patches")
            # Apply multiple patches
            updated_spec = current_spec
            for patch_dict in patch_data["patches"]
                patch = ConfigPatch(
                    patch_dict["operation"],
                    patch_dict["path"],
                    patch_dict["value"]
                )
                updated_spec = apply_config_patch(updated_spec, patch)
            end
        else
            # Single patch
            patch = ConfigPatch(
                patch_data["operation"],
                patch_data["path"],
                patch_data["value"]
            )
            updated_spec = apply_config_patch(current_spec, patch)
        end
        
        # Update stored spec
        ACTIVE_MODELS[model_id]["spec"] = updated_spec
        ACTIVE_MODELS[model_id]["status"] = "updated"
        ACTIVE_MODELS[model_id]["model"] = nothing  # Clear cached model
        ACTIVE_MODELS[model_id]["solution"] = nothing  # Clear cached solution
        
        response_data = Dict(
            "model_id" => model_id,
            "status" => "updated"
        )
        
        return HTTP.Response(200, [], JSON3.write(response_data))
        
    catch e
        error_response = Dict(
            "error" => "Failed to update model config",
            "message" => string(e)
        )
        return HTTP.Response(400, [], JSON3.write(error_response))
    end
end

function solve_model_endpoint(req::HTTP.Request)
    model_id = extract_model_id(req.target)
    
    if !haskey(ACTIVE_MODELS, model_id)
        return HTTP.Response(404, [], JSON3.write(Dict("error" => "Model not found")))
    end
    
    try
        # Get or build the model
        model_data = ACTIVE_MODELS[model_id]
        
        if model_data["model"] === nothing
            # Build the model
            spec = model_data["spec"]
            model = build_model(spec)
            ACTIVE_MODELS[model_id]["model"] = model
        else
            model = model_data["model"]
        end
        
        # Solve the model
        solution = solve_model(model)
        
        # Store solution
        ACTIVE_MODELS[model_id]["solution"] = solution
        ACTIVE_MODELS[model_id]["status"] = "solved"
        
        return HTTP.Response(200, [], JSON3.write(solution))
        
    catch e
        error_response = Dict(
            "error" => "Failed to solve model",
            "message" => string(e)
        )
        ACTIVE_MODELS[model_id]["status"] = "error"
        return HTTP.Response(500, [], JSON3.write(error_response))
    end
end

function get_solution(req::HTTP.Request)
    model_id = extract_model_id(req.target)
    
    if !haskey(ACTIVE_MODELS, model_id)
        return HTTP.Response(404, [], JSON3.write(Dict("error" => "Model not found")))
    end
    
    model_data = ACTIVE_MODELS[model_id]
    
    if model_data["solution"] === nothing
        return HTTP.Response(404, [], JSON3.write(Dict("error" => "No solution available. Run solve first.")))
    end
    
    return HTTP.Response(200, [], JSON3.write(model_data["solution"]))
end

function delete_model(req::HTTP.Request)
    model_id = extract_model_id(req.target)
    
    if !haskey(ACTIVE_MODELS, model_id)
        return HTTP.Response(404, [], JSON3.write(Dict("error" => "Model not found")))
    end
    
    delete!(ACTIVE_MODELS, model_id)
    
    return HTTP.Response(200, [], JSON3.write(Dict("message" => "Model deleted")))
end

function create_ui_spec_endpoint(req::HTTP.Request)
    model_id = extract_model_id(req.target)
    
    if !haskey(ACTIVE_MODELS, model_id)
        return HTTP.Response(404, [], JSON3.write(Dict("error" => "Model not found")))
    end
    
    try
        # Parse request body for query context
        body = String(req.body)
        request_data = isempty(body) ? Dict() : JSON3.read(body)
        query = get(request_data, "query", "")
        
        # Get model spec
        spec = ACTIVE_MODELS[model_id]["spec"]
        
        # Create UI specification
        ui_spec = create_ui_spec(spec, query)
        
        return HTTP.Response(200, [], JSON3.write(ui_spec))
        
    catch e
        error_response = Dict(
            "error" => "Failed to create UI spec",
            "message" => string(e)
        )
        return HTTP.Response(500, [], JSON3.write(error_response))
    end
end

# Natural language parsing has been moved to the frontend using Gemini API

# Helper functions
function extract_model_id(target::String)::String
    # Extract model ID from URL path like "/models/model_123/solve"
    parts = split(target, "/")
    model_index = findfirst(x -> x == "models", parts)
    if model_index !== nothing && length(parts) > model_index
        return parts[model_index + 1]
    end
    throw(ArgumentError("Invalid model URL: $target"))
end

# Gemini API integration has been moved to the frontend

function generate_ui_updates(patches::Vector{Dict{String, Any}})::Vector{Dict{String, Any}}
    ui_updates = Dict{String, Any}[]
    
    for patch in patches
        if haskey(patch, "path") && length(patch["path"]) >= 2
            section = patch["path"][1]
            key = patch["path"][2]
            
            if section == "indexes" && key == "days"
                push!(ui_updates, Dict(
                    "type" => "update_control",
                    "control_id" => "date_range",
                    "value" => [patch["value"]["start"], patch["value"]["end"]]
                ))
            elseif section == "parameters" && contains(key, "multiplier")
                push!(ui_updates, Dict(
                    "type" => "update_control",
                    "control_id" => "$(key)_slider",
                    "value" => patch["value"]
                ))
            end
        end
    end
    
    return ui_updates
end

# Export API functions
export start_api_server