struct OrchestrationEvent
  slot::Int
  onset::Float64
  duration::Float64
  sample_index::Int
  gain::Float64
  error_before::Float64
  error_after::Float64
end

function _cosine_distance(a::Vector{Float64}, b::Vector{Float64})
  denominator = norm(a) * norm(b)
  denominator <= eps() && return 1.0
  return 1.0 - clamp(dot(a, b) / denominator, -1.0, 1.0)
end

function _candidate_score(target::AudioFeature, sample::IndexedSample, previous_instruments::Set{String}, continuity::Float64)
  spectral = _cosine_distance(target.spectrum, sample.feature.spectrum)
  chroma = _cosine_distance(target.chroma, sample.feature.chroma)
  shape = abs(target.centroid - sample.feature.centroid) + 0.35 * abs(target.flatness - sample.feature.flatness)
  continuation_bonus = sample.entry.instrument in previous_instruments ? continuity : 0.0
  return 0.68 * spectral + 0.22 * chroma + 0.10 * shape - continuation_bonus
end

"""
Sparse non-negative pursuit on perceptual spectral atoms. Candidate ranking includes
pitch-class/shape distance; residual fitting determines the actual mixture and gains.
"""
function optimize_slot(target::AudioFeature, inventory::Vector{IndexedSample}; max_voices::Int=4,
                       sparsity::Float64=0.025, continuity::Float64=0.04,
                       previous_instruments=Set{String}())
  target.rms < 1e-4 && return Tuple{Int,Float64,Float64,Float64}[]
  ranked = sortperm(1:length(inventory); by=i -> _candidate_score(target, inventory[i], previous_instruments, continuity))
  pool = ranked[1:min(length(ranked), 96)]
  residual = copy(target.spectrum)
  initial_error = norm(residual)
  selected = Tuple{Int,Float64,Float64,Float64}[]
  used_instruments = Set{String}()

  for _ in 1:max_voices
    best_index, best_gain, best_error = 0, 0.0, norm(residual)
    for index in pool
      instrument = inventory[index].entry.instrument
      instrument in used_instruments && continue
      atom = inventory[index].feature.spectrum
      gain = clamp(dot(atom, residual) / max(dot(atom, atom), 1e-12), 0.0, 2.5)
      gain <= 0 && continue
      candidate_error = norm(max.(residual .- gain .* atom, 0.0)) + sparsity * (length(selected) + 1)
      if candidate_error < best_error
        best_index, best_gain, best_error = index, gain, candidate_error
      end
    end
    best_index == 0 && break
    before = norm(residual)
    residual = max.(residual .- best_gain .* inventory[best_index].feature.spectrum, 0.0)
    after = norm(residual)
    after >= before - sparsity && break
    push!(selected, (best_index, best_gain, before, after))
    push!(used_instruments, inventory[best_index].entry.instrument)
  end

  isempty(selected) && !isempty(pool) && push!(selected, (first(pool), 0.35, initial_error, initial_error))
  loudness_scale = clamp(target.rms / 0.16, 0.08, 1.6)
  return [(index, clamp(gain * loudness_scale, 0.03, 1.5), before, after) for (index, gain, before, after) in selected]
end

function optimize_sequence(features::Vector{AudioFeature}, inventory::Vector{IndexedSample}, step_seconds::Float64;
                           max_voices::Int=4, sparsity::Float64=0.025, continuity::Float64=0.04)
  events = OrchestrationEvent[]
  previous_instruments = Set{String}()
  for (slot, target) in enumerate(features)
    choices = optimize_slot(target, inventory; max_voices, sparsity, continuity, previous_instruments)
    next_instruments = Set{String}()
    for (sample_index, gain, before, after) in choices
      push!(events, OrchestrationEvent(slot, (slot - 1) * step_seconds, step_seconds,
        sample_index, gain, before, after))
      push!(next_instruments, inventory[sample_index].entry.instrument)
    end
    previous_instruments = next_instruments
  end
  return events
end
