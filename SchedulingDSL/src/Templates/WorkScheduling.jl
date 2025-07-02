# Work scheduling template implementation

function work_scheduling_template(spec::ModelSpec)::Model
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    
    # Extract indexes
    days = get_index_values(spec, :days)
    candidates = get_index_values(spec, :candidates)
    skills = get_index_values(spec, :skills)
    scenarios = haskey(spec.indexes, :scenarios) ? get_index_values(spec, :scenarios) : ["base"]
    
    # Extract parameters
    demand_data = get_parameter_data(spec, :demand)
    candidate_skills_data = get_parameter_data(spec, :candidate_skills)
    cost_data = haskey(spec.parameters, :cost_month) ? get_parameter_data(spec, :cost_month) : nothing
    
    # Decision variables
    @variable(model, assign[candidates, days, skills], Bin)
    @variable(model, hire[candidates], Bin)
    
    # Demand constraints
    for scenario in scenarios
        for day in days
            for skill in skills
                # Find demand for this scenario/day/skill
                demand_rows = filter(row -> 
                    row.scenario == scenario && 
                    Date(row.day) == day && 
                    row.skill == skill, 
                    demand_data)
                
                if !isempty(demand_rows)
                    demand_value = demand_rows[1].value
                    @constraint(model, 
                        sum(assign[c, day, skill] for c in candidates 
                            if has_skill(candidate_skills_data, c, skill)) >= demand_value)
                end
            end
        end
    end
    
    # Skill constraints - only assign if candidate has skill
    for candidate in candidates
        for day in days
            for skill in skills
                if !has_skill(candidate_skills_data, candidate, skill)
                    @constraint(model, assign[candidate, day, skill] == 0)
                end
            end
        end
    end
    
    # Hiring constraints - must hire to assign
    for candidate in candidates
        for day in days
            for skill in skills
                @constraint(model, assign[candidate, day, skill] <= hire[candidate])
            end
        end
    end
    
    # Daily work limit per person
    max_daily_assignments = get(spec.options, :max_daily_assignments, 2)
    for candidate in candidates
        for day in days
            @constraint(model, 
                sum(assign[candidate, day, skill] for skill in skills) <= max_daily_assignments)
        end
    end
    
    # Objective function
    if cost_data !== nothing
        @objective(model, Min, 
            sum(cost_data[candidate] * hire[candidate] for candidate in candidates if haskey(cost_data, candidate)))
    else
        # Default objective: minimize total assignments
        @objective(model, Min, sum(assign))
    end
    
    return model
end

# Helper function to check if candidate has skill
function has_skill(candidate_skills_data::DataFrame, candidate::String, skill::String)::Bool
    skill_rows = filter(row -> 
        row.candidate == candidate && 
        row.skill == skill, 
        candidate_skills_data)
    
    return !isempty(skill_rows) && skill_rows[1].has_skill
end

# Register the template
function __init__()
    register_template!("work_scheduling", work_scheduling_template)
    
    # Register common constraints
    register_constraint!("time_window", time_window_constraint)
    register_constraint!("max_consecutive_days", max_consecutive_days_constraint)
    register_constraint!("min_rest_days", min_rest_days_constraint)
    
    # Register common objectives
    register_objective!("minimize_cost", minimize_cost_objective)
    register_objective!("maximize_coverage", maximize_coverage_objective)
    register_objective!("balance_workload", balance_workload_objective)
end

# Constraint functions
function time_window_constraint(model::Model, spec::ModelSpec, args::Dict{Symbol, Any})
    candidate = get(args, :candidate, "")
    start_time = get(args, :start_time, 9)
    end_time = get(args, :end_time, 17)
    
    if haskey(object_dictionary(model), :assign)
        assign = model[:assign]
        days = get_index_values(spec, :days)
        skills = get_index_values(spec, :skills)
        
        # Add constraint that this candidate can only work within time window
        # This is a simplified version - in practice, you'd need time-based data
        for day in days
            for skill in skills
                if hour(day) < start_time || hour(day) > end_time
                    @constraint(model, assign[candidate, day, skill] == 0)
                end
            end
        end
    end
end

function max_consecutive_days_constraint(model::Model, spec::ModelSpec, args::Dict{Symbol, Any})
    max_consecutive = get(args, :max_consecutive, 5)
    
    if haskey(object_dictionary(model), :assign)
        assign = model[:assign]
        candidates = get_index_values(spec, :candidates)
        days = get_index_values(spec, :days)
        skills = get_index_values(spec, :skills)
        
        # Add constraints for maximum consecutive working days
        for candidate in candidates
            for i in 1:(length(days) - max_consecutive)
                consecutive_days = days[i:i+max_consecutive]
                @constraint(model, 
                    sum(assign[candidate, day, skill] 
                        for day in consecutive_days, skill in skills) <= max_consecutive)
            end
        end
    end
end

function min_rest_days_constraint(model::Model, spec::ModelSpec, args::Dict{Symbol, Any})
    min_rest = get(args, :min_rest, 1)
    
    if haskey(object_dictionary(model), :assign)
        assign = model[:assign]
        candidates = get_index_values(spec, :candidates)
        days = get_index_values(spec, :days)
        skills = get_index_values(spec, :skills)
        
        # Add constraints for minimum rest days between work periods
        for candidate in candidates
            for i in 1:(length(days) - min_rest - 1)
                work_today = sum(assign[candidate, days[i], skill] for skill in skills)
                work_after_rest = sum(assign[candidate, days[i + min_rest + 1], skill] for skill in skills)
                
                # If working today and after rest period, ensure no work during rest
                for rest_day_idx in (i+1):(i+min_rest)
                    if rest_day_idx <= length(days)
                        rest_work = sum(assign[candidate, days[rest_day_idx], skill] for skill in skills)
                        @constraint(model, work_today + work_after_rest + rest_work <= 1)
                    end
                end
            end
        end
    end
end

# Objective functions
function minimize_cost_objective(model::Model, spec::ModelSpec, args::Dict{Symbol, Any})
    cost_multiplier = get(args, :multiplier, 1.0)
    
    if haskey(spec.parameters, :cost_month)
        cost_data = get_parameter_data(spec, :cost_month)
        candidates = get_index_values(spec, :candidates)
        
        if haskey(object_dictionary(model), :hire)
            hire = model[:hire]
            @objective(model, Min, 
                cost_multiplier * sum(cost_data[candidate] * hire[candidate] 
                                    for candidate in candidates if haskey(cost_data, candidate)))
        end
    end
end

function maximize_coverage_objective(model::Model, spec::ModelSpec, args::Dict{Symbol, Any})
    coverage_weight = get(args, :weight, 1.0)
    
    if haskey(object_dictionary(model), :assign)
        assign = model[:assign]
        @objective(model, Max, coverage_weight * sum(assign))
    end
end

function balance_workload_objective(model::Model, spec::ModelSpec, args::Dict{Symbol, Any})
    if haskey(object_dictionary(model), :assign)
        assign = model[:assign]
        candidates = get_index_values(spec, :candidates)
        days = get_index_values(spec, :days)
        skills = get_index_values(spec, :skills)
        
        # Create workload variables
        @variable(model, workload[candidates] >= 0)
        @variable(model, max_workload >= 0)
        
        # Define workload for each candidate
        for candidate in candidates
            @constraint(model, workload[candidate] == 
                sum(assign[candidate, day, skill] for day in days, skill in skills))
        end
        
        # Define maximum workload
        for candidate in candidates
            @constraint(model, max_workload >= workload[candidate])
        end
        
        # Minimize maximum workload (balancing)
        @objective(model, Min, max_workload)
    end
end