#!/usr/bin/env python3
"""Verify and safely extract user-supplied CC BY 4.0 Sketchfab glTF packages.

The archives are prepared outside the repository and placed in sketchfab_drop/.
All four archives are SHA-256 pinned and keep the original license.txt.
Extraction occurs during CI before the Godot import, never at runtime.
"""
import argparse
import hashlib
import json
import shutil
import sys
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
DROP = ROOT / "sketchfab_drop"
OUT = ROOT / "models" / "sketchfab"
CATALOG = DROP / "catalog.json"
MAX_MEMBER = 45 * 1024 * 1024
MAX_ARCHIVE = 180 * 1024 * 1024


def unpack(strict: bool) -> int:
    info = json.loads(CATALOG.read_text(encoding="utf-8"))
    if info.get("schemaVersion") != 1 or info.get("license") != "CC-BY-4.0":
        raise ValueError("Unexpected Sketchfab catalog version or license")
    extracted = 0
    for item in info["models"]:
        slug = item["id"]
        if not slug.replace("_", "").isalnum():
            raise ValueError("Unsafe asset id")
        source = DROP / (slug + ".zip")
        if not source.is_file():
            if strict:
                raise FileNotFoundError("Missing checked Sketchfab source ZIP: " + str(source))
            print("Awaiting uploaded source:", source.relative_to(ROOT))
            continue
        archive_bytes = source.read_bytes()
        if len(archive_bytes) != item["bytes"]:
            raise ValueError("Unexpected source ZIP size for " + slug)
        if hashlib.sha256(archive_bytes).hexdigest() != item["sha256"]:
            raise ValueError("Source SHA-256 mismatch for " + slug)
        destination = OUT / slug
        if destination.exists():
            shutil.rmtree(destination)
        destination.mkdir(parents=True)
        total = 0
        with zipfile.ZipFile(source) as z:
            names = z.namelist()
            if "scene.gltf" not in names or "scene.bin" not in names or "license.txt" not in names:
                raise ValueError("Incomplete Sketchfab glTF archive: " + slug)
            for entry in z.infolist():
                if entry.is_dir():
                    continue
                if entry.file_size > MAX_MEMBER:
                    raise ValueError("Oversized member: " + entry.filename)
                total += entry.file_size
                if total > MAX_ARCHIVE:
                    raise ValueError("Oversized unpacked archive: " + slug)
                part = PurePosixPath(entry.filename)
                if part.is_absolute() or any(n in (".", "..") for n in part.parts) \
                        or "\\" in entry.filename:
                    raise ValueError("Archive path traversal: " + entry.filename)
                if (entry.external_attr >> 16) & 0o170000 == 0o120000:
                    raise ValueError("Symlink archive entry rejected: " + entry.filename)
                target = destination.joinpath(*part.parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                with z.open(entry) as inp, target.open("wb") as out:
                    shutil.copyfileobj(inp, out)
        license_text = (destination / "license.txt").read_text(encoding="utf-8")
        if "CC-BY-4.0" not in license_text or item["sourceUrl"] not in license_text \
                or item["author"] not in license_text:
            raise ValueError("License attribution mismatch in " + slug)
        gltf = json.loads((destination / "scene.gltf").read_text(encoding="utf-8"))
        if str(gltf.get("asset", {}).get("version")) != "2.0":
            raise ValueError("Invalid glTF 2.0 archive: " + slug)
        for entry in gltf.get("buffers", []) + gltf.get("images", []):
            uri = entry.get("uri")
            if uri and not uri.startswith("data:"):
                ref = PurePosixPath(uri)
                if ref.is_absolute() or ".." in ref.parts \
                        or not (destination.joinpath(*ref.parts)).is_file():
                    raise ValueError("Missing or unsafe glTF dependency: " + uri)
        if slug == "poker_set" and not (destination / "poker_props.glb").exists():
            raise ValueError("Lightweight 3D poker props are missing")
        print("Verified Sketchfab model:", slug, "files", len(names), "unpacked bytes", total, flush=True)
        extracted += 1
    if strict and extracted != len(info["models"]):
        raise ValueError("Four original models are required for the integration build")
    print("Imported Sketchfab models:", extracted, "/", len(info["models"]))
    return extracted


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--require-all", action="store_true")
    args = p.parse_args()
    try:
        unpack(args.require_all)
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        print("Sketchfab asset validation FAILED:", str(error), file=sys.stderr)
        sys.exit(1)
