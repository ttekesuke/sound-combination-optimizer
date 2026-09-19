const REPO_ROOT = normpath(joinpath(@__DIR__, ".."))
cd(REPO_ROOT)

function load_dotenv(path)
  isfile(path) || return
  for raw in eachline(path)
    line = strip(raw)
    (isempty(line) || startswith(line, "#") || !occursin("=", line)) && continue
    key, value = split(line, "="; limit=2)
    key, value = strip(key), strip(value)
    if length(value) >= 2 && first(value) == last(value) && first(value) in ('\"', '\'')
      value = value[2:end-1]
    end
    haskey(ENV, key) || (ENV[key] = value)
  end
end

load_dotenv(joinpath(REPO_ROOT, ".env"))

using Genie
using SoundCombinationOptimizer
include(joinpath(REPO_ROOT, "routes.jl"))

Genie.config.run_as_server = true
Genie.config.server_host = get(ENV, "HOST", "127.0.0.1")
Genie.config.server_port = parse(Int, get(ENV, "PORT", "9111"))
Genie.up(async=false)
