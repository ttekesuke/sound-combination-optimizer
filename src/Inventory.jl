struct SampleEntry
  path::String
  instrument::String
  note::String
  midi::Int
  dynamic::String
  technique::String
  source::String
end

struct IndexedSample
  entry::SampleEntry
  feature::AudioFeature
end

const INVENTORY_CACHE = Ref{Tuple{String,Float64,Vector{IndexedSample}}}(("", 0.0, IndexedSample[]))

manifest_path() = abspath(get(ENV, "SOUND_LIBRARY_MANIFEST", joinpath("data", "library", "manifest.csv")))

function _csv_fields(line::AbstractString)
  fields, current = String[], IOBuffer()
  quoted = false
  chars = collect(line)
  index = 1
  while index <= length(chars)
    char = chars[index]
    if char == '\"'
      if quoted && index < length(chars) && chars[index + 1] == '\"'
        print(current, '\"'); index += 1
      else
        quoted = !quoted
      end
    elseif char == ',' && !quoted
      push!(fields, String(take!(current)))
    else
      print(current, char)
    end
    index += 1
  end
  push!(fields, String(take!(current)))
  return fields
end

function read_manifest(path::AbstractString=manifest_path())
  isfile(path) || error("Sound library manifest was not found: $(path)")
  lines = filter(line -> !isempty(strip(line)), readlines(path))
  length(lines) <= 1 && return SampleEntry[]
  base = dirname(path)
  entries = SampleEntry[]
  for line in lines[2:end]
    fields = _csv_fields(line)
    length(fields) >= 7 || continue
    sample_path = isabspath(fields[1]) ? fields[1] : normpath(joinpath(base, fields[1]))
    isfile(sample_path) || continue
    midi = tryparse(Int, fields[4])
    midi === nothing && continue
    push!(entries, SampleEntry(sample_path, fields[2], fields[3], midi, fields[5], fields[6], fields[7]))
  end
  return entries
end

function load_inventory(; force=false)
  path = manifest_path()
  modified = isfile(path) ? mtime(path) : 0.0
  cached_path, cached_modified, cached = INVENTORY_CACHE[]
  !force && cached_path == path && cached_modified == modified && !isempty(cached) && return cached
  entries = read_manifest(path)
  indexed = IndexedSample[]
  for entry in entries
    try
      signal, fs = load_audio(entry.path; target_rate=ANALYSIS_RATE)
      useful = signal[1:min(length(signal), round(Int, 1.5 * fs))]
      push!(indexed, IndexedSample(entry, extract_feature(useful, fs)))
    catch err
      @warn "Skipping unreadable sample" path=entry.path exception=err
    end
  end
  INVENTORY_CACHE[] = (path, modified, indexed)
  return indexed
end

function inventory_status()
  samples = load_inventory()
  instruments = sort(unique([sample.entry.instrument for sample in samples]))
  Dict(
    "ok" => true,
    "sampleCount" => length(samples),
    "instrumentCount" => length(instruments),
    "instruments" => instruments,
    "manifest" => manifest_path(),
  )
end
