#!/usr/bin/env julia

using Pkg
Pkg.activate("SchedulingDSL")

# Load environment variables from parent directory .env file
function load_env_file(filepath::String)
    if isfile(filepath)
        for line in readlines(filepath)
            line = strip(line)
            if !isempty(line) && !startswith(line, "#")
                key_value = split(line, "=", limit=2)
                if length(key_value) == 2
                    key = strip(key_value[1])
                    value = strip(key_value[2])
                    ENV[key] = value
                    println("✓ Loaded environment variable: $key")
                end
            end
        end
    else
        println("⚠️  No .env file found at $filepath")
    end
end

# Load .env from parent directory
env_path = joinpath("..", ".env")
load_env_file(env_path)

using SchedulingDSL

println("🚀 Starting SchedulingDSL API Server...")
println("📊 Optimization service will be available at http://localhost:8080")
println("🔍 Julia backend ready for natural language queries")
println("⚡ Press Ctrl+C to stop the server")
println()

try
    start_api_server(8080)
catch e
    if isa(e, InterruptException)
        println("\n👋 Server stopped gracefully")
    else
        println("\n❌ Server error: $e")
        rethrow(e)
    end
end