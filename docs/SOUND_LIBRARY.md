# Sound library preparation

The repository intentionally contains no Philharmonia audio. The Philharmonia sound-sample page allows musical use, including commercial work, but says the samples must not be sold or made available **as-is** as samples or a sampler instrument. Do not publish the raw library in this Git repository or a public Google Drive folder.

## Quick local demo

```bash
python3 scripts/bootstrap_demo_library.py
```

This creates a small clearly-labelled synthetic library.

## Philharmonia import

1. Download the desired official archive from <https://philharmonia.co.uk/resources/sound-samples/>.
2. Install `ffmpeg`.
3. Run:

```bash
python3 scripts/import_philharmonia.py ~/Downloads/philharmonia-samples.zip
```

The importer keeps pitched, parseable files; filters techniques; converts compressed files to 22.05 kHz mono WAV; and writes `data/library/manifest.csv`. To change the allowed technique set:

```bash
python3 scripts/import_philharmonia.py samples/ --techniques normal,arco-normal,staccato,pizzicato
```

Review the manifest and filenames after importing. Source naming is not a stable API, and unpitched percussion, effects, scales, phrases, and ambiguous filenames are intentionally skipped.

## Large/private storage

For an archive that you control, set either `SOUND_LIBRARY_URL` or `GOOGLE_DRIVE_FILE_ID`, install `scripts/requirements.txt`, and run `scripts/fetch_library.py`. Then pass the downloaded archive to `import_philharmonia.py`. Keep credentials and restricted URLs in `.env`, never in Git.
