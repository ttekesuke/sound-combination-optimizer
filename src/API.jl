function _payload_value(payload, key::AbstractString, default)
  try
    haskey(payload, key) ? payload[key] : default
  catch
    default
  end
end

function _decode_audio_data(value::AbstractString)
  encoded = occursin(',', value) ? split(value, ','; limit=2)[2] : value
  return base64decode(encoded)
end

function _event_dict(event::OrchestrationEvent, inventory::Vector{IndexedSample})
  entry = inventory[event.sample_index].entry
  Dict(
    "slot" => event.slot,
    "onset" => round(event.onset; digits=4),
    "duration" => round(event.duration; digits=4),
    "instrument" => entry.instrument,
    "note" => entry.note,
    "midi" => entry.midi,
    "dynamic" => dynamic_mark(event.gain),
    "gain" => round(event.gain; digits=4),
    "technique" => entry.technique,
    "source" => entry.source,
    "residualBefore" => round(event.error_before; digits=5),
    "residualAfter" => round(event.error_after; digits=5),
  )
end

function orchestrate_request(payload)
  audio_value = string(_payload_value(payload, "audioBase64", ""))
  isempty(audio_value) && error("audioBase64 is required")
  tempo = clamp(Float64(_payload_value(payload, "tempo", 120)), 30.0, 300.0)
  subdivision = Int(_payload_value(payload, "subdivision", 8))
  subdivision in (4, 8, 16) || error("subdivision must be 4, 8, or 16")
  max_voices = clamp(Int(_payload_value(payload, "maxVoices", 4)), 1, 8)
  sparsity = clamp(Float64(_payload_value(payload, "sparsity", 0.025)), 0.0, 0.25)
  continuity = clamp(Float64(_payload_value(payload, "continuity", 0.04)), 0.0, 0.25)

  bytes = _decode_audio_data(audio_value)
  max_bytes = parse(Int, get(ENV, "MAX_UPLOAD_MB", "40")) * 1024 * 1024
  length(bytes) <= max_bytes || error("Uploaded file exceeds the configured $(max_bytes ÷ 1024 ÷ 1024) MB limit")

  input_path = tempname() * ".wav"
  write(input_path, bytes)
  try
    target, source_rate = load_audio(input_path)
    isempty(target) && error("The uploaded WAV contains no samples")
    target = resample_audio(target, source_rate, ANALYSIS_RATE)
    segments, step_seconds = split_on_grid(target, ANALYSIS_RATE, tempo, subdivision)
    features = [extract_feature(segment, ANALYSIS_RATE) for segment in segments]
    inventory = load_inventory()
    isempty(inventory) && error("The sound library is empty. Run scripts/bootstrap_demo_library.py or import Philharmonia samples.")

    events = optimize_sequence(features, inventory, step_seconds; max_voices, sparsity, continuity)
    duration = length(segments) * step_seconds
    rendered = synthesize(events, inventory, ANALYSIS_RATE, duration)
    score = musicxml(events, inventory, length(segments), tempo, subdivision)
    mean_residual = isempty(events) ? 1.0 : mean(event.error_after for event in events)

    return Dict(
      "ok" => true,
      "jobId" => string(uuid4()),
      "audioBase64" => wav_base64(rendered, ANALYSIS_RATE),
      "audioMime" => "audio/wav",
      "musicXml" => score,
      "events" => [_event_dict(event, inventory) for event in events],
      "summary" => Dict(
        "tempo" => tempo,
        "subdivision" => subdivision,
        "stepSeconds" => round(step_seconds; digits=5),
        "slotCount" => length(segments),
        "eventCount" => length(events),
        "durationSeconds" => round(duration; digits=3),
        "meanResidual" => round(mean_residual; digits=5),
      ),
    )
  finally
    rm(input_path; force=true)
  end
end
