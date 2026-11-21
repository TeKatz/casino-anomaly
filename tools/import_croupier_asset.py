#!/usr/bin/env python3
"""Verify and unpack the user-selected Sketchfab CC BY 4.0 croupier.

The model is only imported during development/build, never downloaded by
players. If the archive has not been committed, the existing proxy remains.
"""
import argparse
import hashlib
import json
import shutil
import sys
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "sketchfab_drop" / "business_man.zip"
DESTINATION = ROOT / "models" / "croupier"
SHA256 = "6e5e214f579846d387fdcb6d20cd4448e4b518b0bb87b7cfb1f2e97ca676ef54"
SIZE = 10215078
MODEL_URL = "https://sketchfab.com/3d-models/business-man-low-polygon-game-character-b6f6740f883b4749abac47af0045a9dd"
AUTHOR = "manoeldarochadeoliveira"
EXPECTED = {
    "license.txt",
    "scene.gltf",
    "scene.bin",
    "textures/business_suit_man_baseColor.png",
    "textures/business_suit_man_metallicRoughness.png",
    "textures/business_suit_man_normal.png",
}
REQUIRED_ANIMATIONS = {"Rig|idle", "Rig|cycle_talking", "Rig|Eyes blinking"}
MAX_UNPACKED = 20 * 1024 * 1024


def import_model(required: bool) -> bool:
    if not SOURCE.is_file():
        if required:
            raise FileNotFoundError("Missing archive: " + str(SOURCE))
        print("Croupier source archive pending; the intro uses its proxy character.")
        return False
    raw = SOURCE.read_bytes()
    if len(raw) != SIZE or hashlib.sha256(raw).hexdigest() != SHA256:
        raise ValueError("Croupier archive does not match the verified user upload")
    with zipfile.ZipFile(SOURCE) as archive:
        actual = {i.filename for i in archive.infolist() if not i.is_dir()}
        if actual != EXPECTED:
            raise ValueError("Unexpected/missing business man package files")
        total = 0
        for entry in archive.infolist():
            if entry.is_dir():
                continue
            part = PurePosixPath(entry.filename)
            if part.is_absolute() or ".." in part.parts or "\\" in entry.filename:
                raise ValueError("Unsafe archive member path: " + entry.filename)
            if (entry.external_attr >> 16) & 0o170000 == 0o120000:
                raise ValueError("Symlink rejected: " + entry.filename)
            total += entry.file_size
            if total > MAX_UNPACKED:
                raise ValueError("Croupier archive exceeds permitted unpacked size")
        license_text = archive.read("license.txt").decode("utf-8")
        if "CC-BY-4.0" not in license_text or AUTHOR not in license_text \
                or MODEL_URL not in license_text:
            raise ValueError("Missing CC BY 4.0 credit and original source")
        model = json.loads(archive.read("scene.gltf"))
        if model.get("asset", {}).get("version") != "2.0":
            raise ValueError("Expected a glTF 2.0 model")
        names = {str(anim.get("name")) for anim in model.get("animations", [])}
        if not REQUIRED_ANIMATIONS.issubset(names) or not model.get("skins"):
            raise ValueError("The supplied business man rig/animations are missing")
        for entry in model.get("buffers", []) + model.get("images", []):
            uri = entry.get("uri", "")
            if not uri or uri.startswith("data:"):
                continue
            ref = PurePosixPath(uri)
            if ref.is_absolute() or ".." in ref.parts or uri not in actual:
                raise ValueError("Invalid or missing glTF dependency: " + uri)
        DESTINATION.mkdir(parents=True, exist_ok=True)
        for filename in sorted(EXPECTED):
            dest = DESTINATION.joinpath(*PurePosixPath(filename).parts)
            dest.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(filename) as source, dest.open("wb") as output:
                shutil.copyfileobj(source, output)
    print("Verified and imported CC BY 4.0 croupier model: 25 animations, textures and license.")
    return True


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--require", action="store_true")
    args = parser.parse_args()
    try:
        import_model(args.require)
    except (OSError, ValueError, zipfile.BadZipFile, json.JSONDecodeError) as error:
        print("Croupier asset import FAILED:", str(error), file=sys.stderr)
        sys.exit(1)
