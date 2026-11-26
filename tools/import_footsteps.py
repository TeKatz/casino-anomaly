#!/usr/bin/env python3
"""Install the exact user-prepared footstep pack locally, without publishing assets."""
import argparse
import hashlib
import io
import sys
import wave
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ARCHIVE = ROOT / "audio_drop" / "Casino_Anomaly_Footsteps.zip"
OUTPUT = ROOT / "audio" / "footsteps"
SHA256 = "bbc343eded1ecb26ec7cd666e136247da9ba6b4c9501cf22ae016e7766dae53b"
GROUPS = {"wood_walk": 6, "wood_run": 6, "carpet_walk": 6, "carpet_run": 6, "wet_carpet_walk": 12}


def install(archive: Path, output: Path = OUTPUT) -> None:
    raw = archive.read_bytes()
    if hashlib.sha256(raw).hexdigest() != SHA256:
        raise ValueError("Unexpected archive SHA-256; use the original prepared pack.")
    names = [f"{group}/{group}_{i:02d}.wav" for group, count in GROUPS.items() for i in range(1, count + 1)]
    with zipfile.ZipFile(io.BytesIO(raw)) as bundle:
        if set(bundle.namelist()) != set(names) | {"AUDIO_CREDITS.md", "source_manifest.json"} or len(bundle.namelist()) != len(names) + 2:
            raise ValueError("Unexpected archive members.")
        payloads = {}
        for name in names:
            data = bundle.read(name)
            with wave.open(io.BytesIO(data), "rb") as clip:
                if (clip.getnchannels(), clip.getsampwidth(), clip.getframerate(), clip.getnframes(), clip.getcomptype()) != (1, 2, 48000, 48000, "NONE"):
                    raise ValueError(f"Invalid WAV: {name}")
                if len(clip.readframes(48000)) != 96000:
                    raise ValueError(f"Truncated WAV: {name}")
            payloads[name] = data
        for name in ("AUDIO_CREDITS.md", "source_manifest.json"):
            payloads[name] = bundle.read(name)
    for name, data in payloads.items():
        target = output / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    print(f"Installed {len(names)} verified footstep WAVs in {output}. Open Godot to import.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, default=DEFAULT_ARCHIVE)
    args = parser.parse_args()
    try:
        install(args.archive)
    except (OSError, ValueError, wave.Error, zipfile.BadZipFile) as exc:
        print(f"Footstep import failed: {exc}", file=sys.stderr)
        sys.exit(1)
