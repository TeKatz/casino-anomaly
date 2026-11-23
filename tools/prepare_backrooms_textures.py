#!/usr/bin/env python3
"""Extract the three clean Oxygen atlas regions without changing their pixels."""
from pathlib import Path
import hashlib
import zipfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "models/backrooms/oxygen"
ATLAS = PACK / "vol1/backrooms.png"
DEST = PACK / "textures"
ARCHIVE = PACK / "sources/backrooms.zip"
# Coordinates are derived from Wall_Clean, Floor_Clean, Tile_Clean UVs
# in the source OBJ (2731 x 2048 atlas, 3 m x 3 m per tile).
REGIONS = {
    "wall_clean.png": (0, 0, 683, 683),
    "ceiling_clean.png": (0, 683, 683, 1365),
    "floor_clean.png": (0, 1365, 683, 2048),
}

def main():
    with zipfile.ZipFile(ARCHIVE) as source:
        assert hashlib.sha256(ATLAS.read_bytes()).digest() == hashlib.sha256(source.read("backrooms.png")).digest(), "Atlas differs from source ZIP"
    DEST.mkdir(parents=True, exist_ok=True)
    with Image.open(ATLAS) as image:
        assert image.size == (2731, 2048), image.size
        for name, box in REGIONS.items():
            image.crop(box).save(DEST / name, optimize=True)
            print(f"{name}: {box}")
    print("Oxygen clean texture extraction PASS")

if __name__ == "__main__":
    main()
