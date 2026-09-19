const NOTE_NAMES = [("C", 0), ("C", 1), ("D", 0), ("D", 1), ("E", 0), ("F", 0),
                    ("F", 1), ("G", 0), ("G", 1), ("A", 0), ("A", 1), ("B", 0)]

xml_escape(value) = replace(string(value), "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\"" => "&quot;")

function midi_pitch(midi::Int)
  step, alter = NOTE_NAMES[mod(midi, 12) + 1]
  octave = fld(midi, 12) - 1
  return step, alter, octave
end

function dynamic_mark(gain::Float64)
  gain < 0.18 && return "pp"
  gain < 0.36 && return "p"
  gain < 0.70 && return "mf"
  gain < 1.05 && return "f"
  return "ff"
end

function _note_xml(entry::SampleEntry, gain::Float64, duration::Int, note_type::String)
  step, alter, octave = midi_pitch(entry.midi)
  accidental = alter == 0 ? "" : "<alter>$(alter)</alter>"
  dynamic = dynamic_mark(gain)
  """<note><pitch><step>$(step)</step>$(accidental)<octave>$(octave)</octave></pitch><duration>$(duration)</duration><type>$(note_type)</type><notations><dynamics><$(dynamic)/></dynamics></notations></note>"""
end

function musicxml(events::Vector{OrchestrationEvent}, inventory::Vector{IndexedSample}, slot_count::Int,
                  tempo::Float64, subdivision::Int)
  instruments = sort(unique([inventory[event.sample_index].entry.instrument for event in events]))
  isempty(instruments) && (instruments = ["Silence"])
  divisions = 4
  note_duration = div(16, subdivision)
  note_type = Dict(4 => "quarter", 8 => "eighth", 16 => "16th")[subdivision]
  slots_per_measure = subdivision
  by_slot_instrument = Dict{Tuple{Int,String},OrchestrationEvent}()
  for event in events
    instrument = inventory[event.sample_index].entry.instrument
    by_slot_instrument[(event.slot, instrument)] = event
  end

  parts = IOBuffer()
  part_list = IOBuffer()
  for (part_index, instrument) in enumerate(instruments)
    part_id = "P$(part_index)"
    print(part_list, "<score-part id=\"$(part_id)\"><part-name>$(xml_escape(instrument))</part-name></score-part>")
    print(parts, "<part id=\"$(part_id)\">")
    measure_count = max(1, cld(slot_count, slots_per_measure))
    for measure in 1:measure_count
      print(parts, "<measure number=\"$(measure)\">")
      if measure == 1
        print(parts, "<attributes><divisions>$(divisions)</divisions><key><fifths>0</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>")
        print(parts, "<direction placement=\"above\"><direction-type><metronome><beat-unit>quarter</beat-unit><per-minute>$(round(Int, tempo))</per-minute></metronome></direction-type><sound tempo=\"$(tempo)\"/></direction>")
      end
      first_slot = (measure - 1) * slots_per_measure + 1
      for slot in first_slot:min(measure * slots_per_measure, slot_count)
        event = get(by_slot_instrument, (slot, instrument), nothing)
        if event === nothing
          print(parts, "<note><rest/><duration>$(note_duration)</duration><type>$(note_type)</type></note>")
        else
          print(parts, _note_xml(inventory[event.sample_index].entry, event.gain, note_duration, note_type))
        end
      end
      remaining = slots_per_measure - max(0, min(slots_per_measure, slot_count - first_slot + 1))
      for _ in 1:remaining
        print(parts, "<note><rest/><duration>$(note_duration)</duration><type>$(note_type)</type></note>")
      end
      print(parts, "</measure>")
    end
    print(parts, "</part>")
  end

  return """<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="4.0"><work><work-title>Target sound orchestration</work-title></work><identification><creator type="composer">Sound Combination Optimizer</creator></identification><part-list>$(String(take!(part_list)))</part-list>$(String(take!(parts)))</score-partwise>"""
end
