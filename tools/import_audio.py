#!/usr/bin/env python3
"""Verify and unpack the two user-approved Casino Anomaly seamless loops.

GitHub Actions and the local Godot editor use the same ZIP, checksum and
paths. Missing ZIP is a supported pre-upload state: no substitute audio is
silently inserted. Never download copyrighted assets during game runtime.
"""
import argparse
import hashlib
import json
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ARCHIVE = ROOT / "source_assets/audio_drop" / "casino_anomaly_seamless_audio.zip"
DEFAULT_OUTPUT = ROOT / "audio"
ARCHIVE_SHA256 = "51fda271b62575657d86a11390879db8f7f6468f3ea7166298045ff70a9d6d44"
TRACKS = {
    "menu": {
        "name": "hmm_menu_seamless.ogg",
        "sha256": "2ceb4cd58c0ea6a8fe19aabed8db9b52f2549ec00afe9b02cd6721603cc18c69",
        "bytes": 1222176,
        "channels": 2,
        "duration_seconds": 92.754,
    },
    "ambient": {
        "name": "casino_room_tone_seamless.ogg",
        "sha256": "b2385458841299cda368ad523b77d31c95e49ea7d1e1cc008040d34f8a531717",
        "bytes": 117247,
        "channels": 1,
        "duration_seconds": 13.219,
    },
}
EXPECTED_NAMES = {
    "hmm_menu_seamless.ogg",
    "casino_room_tone_seamless.ogg",
    "audio_manifest.json",
    "LICENSE_AND_SOURCES.txt",
}


def import_audio(archive: Path, output: Path, required: bool = False) -> bool:
    if not archive.is_file():
        if required:
            raise FileNotFoundError(f"Audio ZIP missing at {archive}")
        print("Casino audio source ZIP not uploaded yet: silent audio fallback.")
        return False

    raw = archive.read_bytes()
    if hashlib.sha256(raw).hexdigest() != ARCHIVE_SHA256:
        raise ValueError("Casino audio ZIP SHA-256 differs from the user-reviewed package")

    with zipfile.ZipFile(archive) as bundle:
        names = set(bundle.namelist())
        if names != EXPECTED_NAMES:
            raise ValueError(f"Unexpected audio ZIP members: {sorted(names ^ EXPECTED_NAMES)}")
        manifest = json.loads(bundle.read("audio_manifest.json"))
        if manifest.get("schema_version") != 1:
            raise ValueError("Wrong audio manifest schema")
        for role, expected in TRACKS.items():
            entry = manifest["assets"][role]
            if entry.get("filename") != expected["name"]:
                raise ValueError(f"Wrong filename for {role}")
            payload = bundle.read(expected["name"])
            if len(payload) != expected["bytes"]:
                raise ValueError(f"Wrong byte count for {role}")
            if hashlib.sha256(payload).hexdigest() != expected["sha256"]:
                raise ValueError(f"Audio track hash differs for {role}")
            if payload[:4] != b"OggS":
                raise ValueError(f"Expected Ogg Vorbis for {role}")
            if entry.get("samplerate") != 44100 or entry.get("channels") != expected["channels"]:
                raise ValueError(f"Audio stream properties differ for {role}")
            if abs(float(entry.get("duration_seconds", 0)) - expected["duration_seconds"]) > 0.05:
                raise ValueError(f"Audio loop duration differs for {role}")
            if entry.get("processed_sha256") != expected["sha256"]:
                raise ValueError(f"Audio manifest hash differs for {role}")
        credits = bundle.read("LICENSE_AND_SOURCES.txt").decode("utf-8")
        if "Xythe" not in credits or "CC0" not in credits or "NOT established" not in credits:
            raise ValueError("Audio credit metadata is missing")
        output.mkdir(parents=True, exist_ok=True)
        for expected in TRACKS.values():
            (output / expected["name"]).write_bytes(bundle.read(expected["name"]))
    print("Verified both pre-crossfaded Casino Anomaly Ogg loops.")
    return True


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--require", action="store_true",
                        help="Fail if the ZIP is missing; use after the one-time upload.")
    parser.add_argument("--archive", type=Path, default=DEFAULT_ARCHIVE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    try:
        import_audio(args.archive, args.output, required=args.require)
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile,
            json.JSONDecodeError) as error:
        print("Casino audio import failed:", error, file=sys.stderr)
        sys.exit(1)
