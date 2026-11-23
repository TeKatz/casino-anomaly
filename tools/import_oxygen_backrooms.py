#!/usr/bin/env python3
"""Import checksum-pinned Oxygen Backrooms packages for Godot 4.5.

Only trusted, explicitly named assets are extracted. Both original ZIPs are
preserved in the repo for future source editing; no scenes are modified.
"""
from __future__ import annotations

import argparse
import hashlib
import shutil
import sys
import zipfile
from pathlib import Path

PACKS = {
    "vol1": {
        "archive_name": "backrooms.zip",
        "sha256": "b18663967868271c80bc1cea5d3c36351e19641a0bed5739dd69bf62c7c80a84",
        "files": ("backrooms.fbx", "backrooms.png"),
    },
    "vol2": {
        "archive_name": "Backrooms_Vol2_1k.zip",
        "sha256": "30ac9b69152feb9db7befd2fbdd61de9fcd9b94726f56794496878fb5635a1aa",
        "files": ("Backrooms_Vol2_1k.glb",),
    },
}


def import_pack(key: str, archive: Path, target: Path) -> None:
    spec = PACKS[key]
    if not archive.is_file():
        raise ValueError(f"Not found: {archive}")
    with archive.open("rb") as handle:
        digest = hashlib.file_digest(handle, "sha256").hexdigest()
    if digest != spec["sha256"]:
        raise ValueError(
            f"{archive}: SHA256 mismatch ({digest}); expected {spec['sha256']}"
        )
    with zipfile.ZipFile(archive) as source:
        bad = source.testzip()
        if bad:
            raise ValueError(f"{archive}: corrupt entry {bad}")
        if len(set(source.namelist())) != len(source.namelist()):
            raise ValueError(f"{archive}: duplicate archive entries")
        for name in spec["files"]:
            if name not in source.namelist():
                raise ValueError(f"{archive}: missing {name}")
            destination = target / key / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            with source.open(name) as src, destination.open("wb") as dst:
                shutil.copyfileobj(src, dst)
            print(f"Installed {destination}")
    original = target / "sources" / spec["archive_name"]
    original.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(archive, original)
    print(f"Preserved source {original}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vol1", type=Path, required=True)
    parser.add_argument("--vol2", type=Path, required=True)
    parser.add_argument(
        "--repo-root", type=Path, default=Path(__file__).resolve().parents[1]
    )
    args = parser.parse_args()
    target = args.repo_root / "models" / "backrooms" / "oxygen"
    import_pack("vol1", args.vol1, target)
    import_pack("vol2", args.vol2, target)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"Oxygen import failed: {error}", file=sys.stderr)
        sys.exit(1)
