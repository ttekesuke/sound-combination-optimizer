# Algorithm notes

## Implemented MVP

1. Decode the uploaded WAV and resample it to 22.05 kHz mono.
2. Quantize time with `60 / tempo * 4 / subdivision` seconds per slot.
3. Extract a 72-band log-frequency spectrum, chroma, RMS, spectral centroid, and flatness from every target slot and every source sample.
4. Rank source candidates by a weighted perceptual distance. A small continuity bonus favors instruments already used in the previous slot.
5. Run sparse non-negative matching pursuit against the remaining spectral residual. At most one sample per instrument and `maxVoices` samples are selected for each slot.
6. Mix the selected samples at the quantized onsets, then emit WAV, event JSON, and MusicXML.

This is deliberately a fast baseline, not a claim to reproduce Orchidée/Orchidea. The feature extractor, candidate search, optimizer, renderer, and notation writer are separate modules so the optimizer can later be replaced by NSGA-II/III, a mixed-integer model, or a learned embedding reranker.

## Recommended next research iteration

- Treat spectral distance, loudness-envelope distance, temporal modulation, orchestration size, and playability as separate Pareto objectives.
- Use approximate nearest-neighbor retrieval to reduce the library, followed by multi-objective evolutionary search.
- Add a sequence-level transition objective rather than only the current one-slot continuity bonus.
- Evaluate both signal-domain metrics (multi-resolution STFT) and perceptual embeddings, but keep a deterministic signal-feature path for inspectability.
- Return several Pareto alternatives instead of collapsing all preferences into one score.

## Research lineage

- Grégoire Carpentier, Gérard Assayag, and Emmanuel Saint-James, *Solving the Musical Orchestration Problem using Multiobjective Constrained Optimization with a Genetic Local Search Approach* (2010).
- IRCAM Orchidea project: target-based computer-assisted orchestration and constraint-based exploration.
- OpenSheetMusicDisplay: MusicXML rendering in the browser.
