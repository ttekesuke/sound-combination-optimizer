function _apply_fades!(signal::Vector{Float64}, sample_rate::Int)
  fade = min(length(signal) ÷ 2, max(1, round(Int, 0.012 * sample_rate)))
  for index in 1:fade
    factor = (index - 1) / max(fade - 1, 1)
    signal[index] *= factor
    signal[end - index + 1] *= factor
  end
  return signal
end

function synthesize(events::Vector{OrchestrationEvent}, inventory::Vector{IndexedSample}, sample_rate::Int, duration::Float64)
  output = zeros(max(1, ceil(Int, duration * sample_rate)))
  cache = Dict{Int,Vector{Float64}}()
  for event in events
    source = get!(cache, event.sample_index) do
      signal, _ = load_audio(inventory[event.sample_index].entry.path; target_rate=sample_rate)
      signal
    end
    wanted = max(1, round(Int, event.duration * sample_rate))
    clip = copy(source[1:min(length(source), wanted)])
    _apply_fades!(clip, sample_rate)
    start_index = round(Int, event.onset * sample_rate) + 1
    end_index = min(length(output), start_index + length(clip) - 1)
    end_index < start_index && continue
    output[start_index:end_index] .+= event.gain .* clip[1:end_index-start_index+1]
  end
  peak = maximum(abs, output; init=0.0)
  peak > 0.98 && (output .*= 0.98 / peak)
  return output
end

function wav_base64(signal::Vector{Float64}, sample_rate::Int)
  path = tempname() * ".wav"
  try
    wavwrite(signal, path; Fs=sample_rate, nbits=16)
    return base64encode(read(path))
  finally
    rm(path; force=true)
  end
end
