const ANALYSIS_RATE = 22_050
const SPECTRAL_BANDS = 72

struct AudioFeature
  spectrum::Vector{Float64}
  chroma::Vector{Float64}
  rms::Float64
  centroid::Float64
  flatness::Float64
end

function mono_audio(raw)
  x = Float64.(raw)
  ndims(x) == 1 && return vec(x)
  return vec(mean(x; dims=2))
end

function resample_audio(x::Vector{Float64}, source_rate::Real, target_rate::Real)
  source_rate == target_rate && return x
  return DSP.resample(x, Float64(target_rate) / Float64(source_rate))
end

function load_audio(path::AbstractString; target_rate::Union{Nothing,Int}=nothing)
  raw, fs = wavread(path)
  x = mono_audio(raw)
  target_rate === nothing && return x, Int(round(fs))
  return resample_audio(x, fs, target_rate), target_rate
end

function _safe_normalize(v::Vector{Float64})
  n = norm(v)
  n > eps() ? v ./ n : zeros(length(v))
end

function extract_feature(signal::AbstractVector{<:Real}, sample_rate::Int)
  x = Float64.(signal)
  isempty(x) && (x = zeros(256))
  nfft = max(512, 2 ^ ceil(Int, log2(min(max(length(x), 512), 16_384))))
  frame = zeros(nfft)
  copy_count = min(length(x), nfft)
  frame[1:copy_count] .= x[1:copy_count]
  window = 0.5 .- 0.5 .* cos.(2pi .* (0:nfft-1) ./ max(nfft - 1, 1))
  magnitudes = abs.(rfft(frame .* window)) .+ 1e-12
  freqs = (0:length(magnitudes)-1) .* (sample_rate / nfft)

  edges = exp.(range(log(35.0), log(min(sample_rate / 2, 11_000.0)); length=SPECTRAL_BANDS + 1))
  bands = zeros(SPECTRAL_BANDS)
  for band in 1:SPECTRAL_BANDS
    indexes = findall(f -> edges[band] <= f < edges[band + 1], freqs)
    !isempty(indexes) && (bands[band] = mean(@view magnitudes[indexes]))
  end
  bands = _safe_normalize(log1p.(bands))

  chroma = zeros(12)
  for index in eachindex(freqs)
    frequency = freqs[index]
    frequency < 35 && continue
    midi = round(Int, 69 + 12 * log2(frequency / 440))
    chroma[mod(midi, 12) + 1] += magnitudes[index]
  end
  chroma = _safe_normalize(chroma)

  power_sum = sum(magnitudes)
  centroid = power_sum > 0 ? sum(freqs .* magnitudes) / power_sum / (sample_rate / 2) : 0.0
  geometric = exp(mean(log.(magnitudes)))
  flatness = geometric / max(mean(magnitudes), 1e-12)
  rms = sqrt(mean(abs2, x))
  return AudioFeature(bands, chroma, rms, centroid, flatness)
end

function feature_vector(feature::AudioFeature)
  vcat(feature.spectrum, 0.45 .* feature.chroma, [0.16 * feature.centroid, 0.08 * feature.flatness])
end

function split_on_grid(signal::Vector{Float64}, sample_rate::Int, tempo::Float64, subdivision::Int)
  step_seconds = 60.0 / tempo * 4.0 / subdivision
  exact_step_samples = max(1.0, step_seconds * sample_rate)
  count = max(1, ceil(Int, length(signal) / exact_step_samples - 1e-12))
  segments = Vector{Vector{Float64}}(undef, count)
  for index in 1:count
    first_sample = round(Int, (index - 1) * exact_step_samples) + 1
    last_sample = min(round(Int, index * exact_step_samples), length(signal))
    segments[index] = first_sample <= last_sample ? signal[first_sample:last_sample] : Float64[]
  end
  return segments, step_seconds
end
