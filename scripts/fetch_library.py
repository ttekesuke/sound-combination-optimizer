#!/usr/bin/env python3
"""Fetch an administrator-owned library archive from a URL or private Google Drive."""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default=os.getenv("SOUND_LIBRARY_URL", ""))
    parser.add_argument("--drive-id", default=os.getenv("GOOGLE_DRIVE_FILE_ID", ""))
    parser.add_argument("--output", type=Path, default=Path("data/library/library.zip"))
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.drive_id:
        subprocess.run([sys.executable, "-m", "gdown", args.drive_id, "-O", str(args.output)], check=True)
    elif args.url:
        subprocess.run(["curl", "--fail", "--location", "--retry", "3", "--output", str(args.output), args.url], check=True)
    else:
        parser.error("Set SOUND_LIBRARY_URL or GOOGLE_DRIVE_FILE_ID")
    print(args.output)


if __name__ == "__main__":
    main()
