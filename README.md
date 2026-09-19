# Sound Combination Optimizer

A Julia/Genie + Vue/Vuetify web application for target-based acoustic orchestration. Upload one target WAV, choose a tempo and rhythmic subdivision, and the server searches its pre-indexed instrumental samples for a sparse combination that approximates each time slot. The response includes a synthesized WAV, an inspectable event list, and MusicXML rendered with OpenSheetMusicDisplay.

## Current vertical slice

- WAV upload from the browser (target audio is the only required user input)
- 40–240 BPM and quarter/eighth/sixteenth-note grids
- perceptual log-spectrum, chroma, RMS, centroid, and flatness features
- sparse non-negative residual pursuit with instrument continuity bias
- configurable maximum polyphony, sparsity, and continuity
- server-side sample mixing and downloadable result WAV
- multi-part MusicXML and OpenSheetMusicDisplay score rendering
- deterministic demo library generator
- Philharmonia archive filtering/conversion/manifest tooling
- optional direct URL or private Google Drive archive fetch
- Docker Compose development/production-shaped runtime and CI

## Start with Docker

```bash
docker compose up --build
```

Open <http://localhost:8080>. The API is also exposed at <http://localhost:9111/api/health>. On first image build, a tiny synthetic library is generated so the complete flow can be exercised without redistributing third-party samples.

## Start without Docker

Requirements: Julia 1.10/1.11, Node.js 22+, Python 3, and `ffmpeg` for compressed-library import.

```bash
python3 scripts/bootstrap_demo_library.py
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. scripts/start_server.jl
```

In a second terminal:

```bash
cd frontend
npm install
npm run dev
```

Open <http://localhost:5173>.

## API

`POST /api/orchestrate`

```json
{
  "audioBase64": "UklGR...",
  "tempo": 120,
  "subdivision": 8,
  "maxVoices": 4,
  "sparsity": 0.025,
  "continuity": 0.04
}
```

The response contains `audioBase64`, `musicXml`, `events`, and a `summary`. Uploads default to 40 MB maximum (`MAX_UPLOAD_MB`).

## Sound library

The runtime reads `data/library/manifest.csv`. Audio files are ignored by Git. See [Sound library preparation](docs/SOUND_LIBRARY.md) before importing Philharmonia samples or placing an archive in Google Drive.

The Philharmonia page says the library is free to use for music, including commercial work, but raw samples may not be sold or made available as-is. This repository therefore includes import tooling and metadata only—not the sample files.

## Algorithm and roadmap

The implemented optimizer is a fast, inspectable baseline inspired by target-based computer-assisted orchestration rather than a literal Orchidée clone. See [Algorithm notes](docs/ALGORITHM.md) for the current objective and the planned Pareto/multi-objective stage.

## Structure

```text
src/                      Julia feature/search/synthesis/MusicXML modules
frontend/                 Vue 3 + Vuetify + Vite + OSMD
scripts/                  server, demo generator, import/fetch tools
data/library/manifest.csv server-side sample inventory
docs/                     algorithm and library decisions
test/                     Julia unit tests
```
