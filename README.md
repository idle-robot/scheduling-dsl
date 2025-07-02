# SchedulingDSL - Natural Language Workforce Optimization

A Julia package that allows users to define and solve workforce scheduling and logistics optimization problems through natural language queries and a declarative configuration system.

## 🎯 Overview

SchedulingDSL transforms complex optimization problems into accessible, user-friendly interfaces:

- **Natural Language Interface**: "Show me next week's schedule with high kitchen demand"
- **Declarative Configuration**: Define problems in YAML without writing code
- **Interactive Visualizations**: Real-time Gantt charts, heatmaps, and metrics
- **Flexible Templates**: Extensible system for different optimization problems
- **Multiple Data Sources**: CSV, JSON, API, and function-based data loading

## 🏗 Architecture

```
SchedulingDSL/
├── src/
│   ├── ModelSpec.jl          # Typed configuration structures
│   ├── ConfigParser.jl       # YAML/JSON loading and validation
│   ├── Sources.jl            # Data source integrations
│   ├── TemplateRegistry.jl   # Model templates and overrides
│   ├── Templates/
│   │   └── WorkScheduling.jl # JuMP model builders
│   └── API.jl               # HTTP backend service
├── frontend/                 # React UI with natural language
├── config/example.yaml      # Sample configuration
└── data/                    # Demo datasets
```

## 🚀 Quick Start

### 1. Setup Environment

```bash
# Copy the environment template and add your Gemini API key
cp frontend/.env.example frontend/.env
# Edit frontend/.env and add your actual GEMINI_API_KEY
```

### 2. Start the Julia Backend

```bash
cd SchedulingDSL
julia server.jl
```

The API server will start on `http://localhost:8080`

### 3. Start the React Frontend

```bash
cd frontend
npm install
npm start
```

The UI will open at `http://localhost:3000`

### 4. Try Natural Language Queries

In the web interface, try queries like:
- "Show me next week's schedule with high kitchen demand"
- "Adjust staff costs by 20% and see the impact"
- "Optimize for Alice to work only 10-4 shifts"

## 📋 Example Configuration

```yaml
template: work_scheduling

indexes:
  days:
    type: date_range
    start: 2025-07-01
    end: 2025-07-30
  candidates:
    type: list
    values: ["Alice", "Bob", "Carol"]
  skills:
    type: list
    values: ["kitchen", "wait", "service"]

parameters:
  demand:
    type: table
    schema: [scenario, day, skill, value]
    source: {type: csv, path: "data/demand.csv"}
  
  cost_month:
    type: dict
    key: candidate
    source: {type: json, path: "data/cost_month.json"}

options:
  max_daily_assignments: 2

overrides:
  objective:
    - function: "minimize_cost_objective"
```

## 🔧 API Endpoints

- `POST /models` - Create optimization model
- `POST /models/{id}/solve` - Solve model
- `PATCH /models/{id}/config` - Update configuration
- `POST /nlp/parse` - Parse natural language queries
- `POST /models/{id}/ui-spec` - Generate UI controls

## 🧠 Natural Language Processing

The system converts natural language into structured configuration changes:

**Query**: "Show high kitchen demand next week"

**Generated Patches**:
```json
[
  {
    "operation": "merge", 
    "path": ["indexes", "days"],
    "value": {"start": "2025-07-08", "end": "2025-07-14"}
  },
  {
    "operation": "merge",
    "path": ["parameters", "demand", "kitchen_multiplier"], 
    "value": 1.5
  }
]
```

## 📊 Visualizations

- **Gantt Charts**: Staff schedules over time
- **Heatmaps**: Skill assignments by person
- **Bar Charts**: Workload distribution
- **Metrics**: Cost, utilization, coverage rates

## 🔌 Extensibility

### Add New Templates
```julia
function my_template(spec::ModelSpec)::Model
    model = Model(HiGHS.Optimizer)
    # Define variables, constraints, objective
    return model
end

register_template!("my_template", my_template)
```

### Add Custom Constraints
```julia
function custom_constraint(model::Model, spec::ModelSpec, args::Dict)
    # Add constraints to model
end

register_constraint!("custom_constraint", custom_constraint)
```

### Add Data Sources
```julia
struct CustomSource <: DataSource
    config::Dict
end

function load_data(source::CustomSource)
    # Load and return data
end
```

## 🧪 Testing

```bash
cd SchedulingDSL
julia -e "using Pkg; Pkg.test()"
```

## 📦 Dependencies

**Julia Backend**:
- JuMP.jl - Optimization modeling
- HiGHS.jl - High-performance solver
- HTTP.jl - Web API server
- DataFrames.jl - Data manipulation

**React Frontend**:
- Ant Design - UI components
- Plotly.js - Interactive visualizations
- Axios - API communication

## 🎯 Use Cases

- **Restaurant Staffing**: Optimize server and kitchen assignments
- **Healthcare Scheduling**: Nurse and doctor shift planning
- **Retail Operations**: Sales associate scheduling
- **Field Services**: Technician routing and scheduling
- **Call Centers**: Agent shift optimization

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details