#!/usr/bin/env python3
"""Import the exact user-supplied CC0 Quaternius UAL Standard GLB.

Use --archive for an offline copy of the original ZIP. CI uses a byte-identical
public mirror pinned to the SHA256 measured from the supplied ZIP.
"""
import argparse
import hashlib
import os
from pathlib import Path
import time
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "models" / "escort_animations" / "UAL1_Standard.glb"
SHA256 = "69591853d817488edaa8fd9bf8fc1d821eaeaf789f8627b3cd23b41c4ed67997"
SIZE = 7618436
URL = "https://github.com/WaviestSun/atelier-packs/releases/download/characters-1/UAL1_Standard.glb"


def verify(data):
    if len(data) != SIZE or hashlib.sha256(data).hexdigest() != SHA256:
        raise ValueError("UAL source differs from the verified original")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path)
    args = parser.parse_args()
    if DEST.exists():
        try:
            verify(DEST.read_bytes())
            print("Verified existing Quaternius UAL asset")
            return
        except ValueError:
            pass
    if args.archive:
        with zipfile.ZipFile(args.archive) as archive:
            matches = [name for name in archive.namelist()
                       if name.endswith("/Unreal-Godot/UAL1_Standard.glb")]
            if len(matches) != 1:
                raise ValueError("Expected one Unreal-Godot/UAL1_Standard.glb")
            data = archive.read(matches[0])
    else:
        for attempt in range(3):
            try:
                req = urllib.request.Request(URL, headers={"User-Agent": "CasinoAnomalyAssetImporter/1"})
                with urllib.request.urlopen(req, timeout=35) as response:
                    data = response.read(SIZE + 1)
                verify(data)
                break
            except (OSError, ValueError) as exc:
                if attempt == 2:
                    raise
                print(f"UAL download retry {attempt + 1}: {exc}", flush=True)
                time.sleep(3 * (attempt + 1))
    verify(data)
    DEST.parent.mkdir(parents=True, exist_ok=True)
    temporary = DEST.with_suffix(".tmp")
    temporary.write_bytes(data)
    os.replace(temporary, DEST)
    print("Quaternius UAL1 Standard verified and installed")


if __name__ == "__main__":
    main()
