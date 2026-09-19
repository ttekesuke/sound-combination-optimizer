using Genie.Router
using Genie.Renderer.Json
using Genie.Requests
using SoundCombinationOptimizer

route("/api/health") do
  json(Dict("status" => "ok", "service" => "sound-combination-optimizer"))
end

route("/api/inventory") do
  try
    json(inventory_status())
  catch err
    json(Dict("ok" => false, "message" => sprint(showerror, err)); status=500)
  end
end

route("/api/orchestrate", method=POST) do
  try
    payload = Requests.jsonpayload()
    payload === nothing && error("JSON request body is required")
    json(orchestrate_request(payload))
  catch err
    @error "orchestration request failed" exception=(err, catch_backtrace())
    json(Dict("ok" => false, "message" => sprint(showerror, err)); status=422)
  end
end
