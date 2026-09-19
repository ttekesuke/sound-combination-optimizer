#!/usr/bin/env python3
"""Normalize a legally downloaded Philharmonia archive/directory into the server library."""
from __future__ import annotations

import argparse
import csv
import re
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

NOTE_RE = re.compile(r"(?P<note>[A-Ga-g])(?P<accidental>[#bs]?)(?P<octave>-?\d)")
ALLOWED_TECHNIQUES = ("arco-normal", "pizzicato", "staccato", "normal", "short", "long")
AUDIO_EXTENSIONS = {".wav", ".mp3", ".ogg", ".flac", ".aif", ".aiff"}


def midi_number(note: str, accidental: str, octave: int) -> int:
    semitone = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}[note.upper()]
    semitone += {"#": 1, "s": 1, "b": -1, "": 0}[accidental]
    return (octave + 1) * 12 + semitone


def metadata(path: Path) -> tuple[str, str, int, str, str] | None:
    stem = path.stem.replace(" ", "_")
    match = NOTE_RE.search(stem)
    if not match:
        return None
    prefix = stem[:match.start()].strip("_-.")
    instrument = re.sub(r"[_-]+", "_", prefix.lower()).strip("_")
    if not instrument:
        return None
    note = f"{match.group('note').upper()}{match.group('accidental')}{match.group('octave')}"
    midi = midi_number(match.group("note"), match.group("accidental"), int(match.group("octave")))
    lowered = stem.lower()
    dynamic = next((value for value in ("fortissimo", "pianissimo", "mezzo-forte", "mezzo-piano", "forte", "piano") if value in lowered), "mf")
    technique = next((value for value in ALLOWED_TECHNIQUES if value in lowered), "normal")
    return instrument, note, midi, dynamic, technique


def convert(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(source),
        "-ac", "1", "-ar", "22050", "-sample_fmt", "s16", str(destination)
    ], check=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path, help="Extracted directory or downloaded ZIP")
    parser.add_argument("--output", type=Path, default=Path("data/library"))
    parser.add_argument("--techniques", default=",".join(ALLOWED_TECHNIQUES))
    args = parser.parse_args()
    allowed = {item.strip().lower() for item in args.techniques.split(",") if item.strip()}
    args.output.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as temporary:
        source_root = args.source
        if args.source.suffix.lower() == ".zip":
            with zipfile.ZipFile(args.source) as archive:
                archive.extractall(temporary)
            source_root = Path(temporary)
        candidates = [p for p in source_root.rglob("*") if p.suffix.lower() in AUDIO_EXTENSIONS]
        rows = []
        for source in candidates:
            parsed = metadata(source)
            if parsed is None:
                continue
            instrument, note, midi, dynamic, technique = parsed
            if technique not in allowed:
                continue
            safe_name = re.sub(r"[^A-Za-z0-9_.-]+", "_", f"{instrument}_{midi}_{dynamic}_{technique}_{len(rows)}.wav")
            destination = args.output / safe_name
            if source.suffix.lower() == ".wav":
                shutil.copy2(source, destination)
            else:
                convert(source, destination)
            rows.append([safe_name, instrument, note, midi, dynamic, technique, "Philharmonia Orchestra"])

    with (args.output / "manifest.csv").open("w", newline="", encoding="utf-8") as output:
        writer = csv.writer(output, lineterminator="\n")
        writer.writerow(["path", "instrument", "note", "midi", "dynamic", "technique", "source"])
        writer.writerows(rows)
    print(f"Imported {len(rows)} usable pitched samples; skipped {len(candidates) - len(rows)} files.")


if __name__ == "__main__":
    main()
