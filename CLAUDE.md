# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Julia Backend
```bash
# Start the API server
julia server.jl

# Run tests
cd SchedulingDSL && julia -e "using Pkg; Pkg.test()"

# Activate the project environment  
cd SchedulingDSL && julia -e "using Pkg; Pkg.activate(.)"

# Add new dependencies
cd SchedulingDSL && julia -e "using Pkg; Pkg.add(\"PackageName\")"
```

### React Frontend
```bash
# Install dependencies and start development server
cd frontend && npm install && npm start

# Build for production
cd frontend && npm run build

# Run frontend tests
cd frontend && npm test
```

### Full System
Start both services for complete functionality:
1. `julia server.jl` (backend on :8080)
2. `cd frontend && npm start` (frontend on :3000)

## Architecture Overview

This is a dual-language system combining Julia optimization backend with React frontend for natural language workforce scheduling.

### Core Architecture Pattern
**Frontend-Driven NLP**: Natural language processing happens in the React frontend using Gemini API, not the backend. Queries are converted to UI control updates and configuration patches client-side.

### Julia Backend (`SchedulingDSL/`)
- **ModelSpec.jl**: Strongly-typed configuration system with validation. Core types: `IndexSpec`, `ParameterSpec`, `DataSource`
- **ConfigParser.jl**: YAML/JSON config loading and `ModelSpec` generation
- **TemplateRegistry.jl**: Function registry for model templates, constraints, and objectives. Global dictionaries: `MODEL_TEMPLATES`, `CONSTRAINT_FUNCTIONS`, `OBJECTIVE_FUNCTIONS`
- **Templates/WorkScheduling.jl**: JuMP model builder for workforce scheduling with constraint/objective functions
- **Sources.jl**: Data loading abstraction supporting CSV, JSON, API, and function sources
- **API.jl**: HTTP server with REST endpoints for model lifecycle (create, solve, update config)

### React Frontend (`frontend/`)
- **GeminiService.js**: Direct Gemini API integration for natural language → UI control mapping
- **ApiService.js**: HTTP client for Julia backend communication
- **App.js**: Main state management and NLP query processing coordinator
- **DynamicControls.js**: UI control generator based on model specifications
- **VisualizationPanel.js**: Plotly.js visualizations (Gantt charts, heatmaps, workload charts)

### Key Data Flow
1. User enters natural language query
2. `GeminiService` converts query to `{ui_updates, config_patches, visualization_focus}`
3. UI controls update immediately based on `ui_updates`
4. `config_patches` sent to Julia backend via API
5. Model re-solved and visualizations updated

### Extension Points
- **New Templates**: Register optimization model builders in `TemplateRegistry.jl`
- **Custom Constraints**: Add constraint functions via `register_constraint!`
- **Data Sources**: Implement `DataSource` subtypes in `Sources.jl`
- **UI Controls**: Add control types in `DynamicControls.js`

### Environment Setup
- Frontend requires `REACT_APP_GEMINI_API_KEY` in `frontend/.env`
- Julia backend loads environment from `../.env` (parent directory)
- Demo data in `SchedulingDSL/data/` and config in `SchedulingDSL/config/`

### Testing Strategy
- Julia: Standard Pkg.test() in `SchedulingDSL/test/runtests.jl`
- React: Jest tests via `npm test`
- Integration: Start both services and test via browser

### Important Implementation Details
- **Config Patching**: Uses JSON Patch-style operations for dynamic model updates
- **Type Safety**: Julia backend enforces strict typing, frontend provides flexible UI
- **Fallback Parsing**: GeminiService includes keyword-based fallback if API fails
- **CORS Handling**: Backend API includes CORS middleware for frontend communication