#!/usr/bin/env python3
"""Restore the two user-supplied ambientCG 4K lobby materials.

Verify original map bytes, not approximate lookalikes. Only the three
required maps are installed; no USD/Blender/displacement files are copied.
Poly Haven stone maps are restored by ensure_assets.py.
"""
import hashlib
import io
import json
import os
import sys
import urllib.request
import zipfile
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
MATERIALS = {"plaster002": "Plaster002", "travertine005": "Travertine005"}
HOSTS = {"ambientcg.com", "acg-download.struffelproductions.com"}
MAX_ZIP = 110_000_000


def digest(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def validate_url(url: str) -> None:
    p = urlsplit(url)
    if p.scheme != "https" or p.hostname not in HOSTS or p.port not in (None, 443):
        raise ValueError("Unapproved ambientCG source: " + url)


def verified(payload: bytes, metadata: dict) -> bool:
    return len(payload) == metadata["bytes"] and digest(payload) == metadata["sha256"] and payload.startswith(b"\xff\xd8\xff")


def ensure_material(folder: str, identifier: str) -> None:
    base = ASSETS / folder
    data = json.loads((base / "ambient_source.json").read_text("utf-8"))
    names = {f"{identifier}_4K-JPG_{suffix}.jpg" for suffix in ("Color", "NormalGL", "Roughness")}
    url = f"https://ambientcg.com/get?file={identifier}_4K-JPG.zip"
    if data["asset"] != identifier or data["license"] != "CC0-1.0" or set(data["maps"]) != names or data["download"] != url:
        raise ValueError("Unexpected lobby material manifest")
    targets = data["maps"]
    missing = []
    for name in sorted(names):
        target = base / name
        if target.exists():
            if not verified(target.read_bytes(), targets[name]):
                raise ValueError("Pinned local material changed: " + name)
        else:
            missing.append(name)
    if not missing:
        print("Verified", identifier, flush=True)
        return
    validate_url(url)
    req = urllib.request.Request(url, headers={"User-Agent": "CasinoAnomalyAssetImport/2.0"})
    with urllib.request.urlopen(req, timeout=120) as response:
        validate_url(response.geturl())
        archive = response.read(MAX_ZIP + 1)
    if len(archive) > MAX_ZIP:
        raise ValueError("Unexpected source archive size")
    # ZIP containers may be repackaged; all three original map hashes are
    # mandatory, regardless of ZIP metadata.
    if digest(archive) != data["uploadedZipSha256"]:
        print("ZIP container differs; checking exact original map hashes", flush=True)
    with zipfile.ZipFile(io.BytesIO(archive)) as z:
        if len(z.infolist()) > 32:
            raise ValueError("Unexpected source archive contents")
        for name in sorted(names):
            meta = targets[name]
            if z.getinfo(name).file_size != meta["bytes"]:
                raise ValueError("Original map size mismatch: " + name)
            payload = z.read(name)
            if not verified(payload, meta):
                raise ValueError("Original map hash mismatch: " + name)
        for name in missing:
            target = base / name
            tmp = target.with_suffix(".download")
            try:
                tmp.write_bytes(z.read(name))
                os.replace(tmp, target)
            finally:
                tmp.unlink(missing_ok=True)
    print("Installed and verified", identifier, flush=True)


def ensure() -> None:
    for folder, identifier in MATERIALS.items():
        ensure_material(folder, identifier)


if __name__ == "__main__":
    try:
        ensure()
    except Exception as error:
        print("Lobby material import FAILED:", str(error), file=sys.stderr)
        sys.exit(1)
