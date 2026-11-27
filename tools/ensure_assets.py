#!/usr/bin/env python3
"""Verify/download original CC0 Poly Haven PBR maps and pin first-import hashes.

Existing assets always retain their pinned hashes. A new asset manifest may
omit hashes once: downloaded bytes are verified, then sha256/size are pinned
into the source.json before the workflow publishes anything.
"""
import hashlib
import json
import shutil
import sys
import tempfile
import urllib.request
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
MAX_BYTES = 30 * 1024 * 1024


def valid(path: Path, metadata: dict) -> bool:
    if "sha256" not in metadata or "bytes" not in metadata:
        return False
    if path.stat().st_size != metadata["bytes"]:
        return False
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest().lower() == metadata["sha256"].lower()


def safe_source(url: str) -> None:
    parsed = urlsplit(url)
    if parsed.scheme != "https" or parsed.hostname != "dl.polyhaven.org" or parsed.port not in (None, 443):
        raise ValueError("Unapproved Poly Haven asset source: " + url)
    if not parsed.path.startswith("/file/ph-assets/Textures/"):
        raise ValueError("Unexpected Poly Haven asset path")


def ensure() -> None:
    manifests = sorted(ASSETS.glob("*/source.json"))
    if not manifests:
        raise ValueError("No Poly Haven asset manifests present")
    for path in manifests:
        info = json.loads(path.read_text(encoding="utf-8"))
        if info.get("license") != "CC0-1.0" or not isinstance(info.get("maps"), dict):
            raise ValueError("Invalid Poly Haven asset metadata: " + str(path))
        updated = False
        for filename, metadata in info["maps"].items():
            if Path(filename).name != filename or "/" in filename or "\\" in filename:
                raise ValueError("Unsafe texture filename")
            safe_source(metadata["url"])
            target = path.parent / filename
            if target.exists() and valid(target, metadata):
                print("Verified", filename, flush=True)
                continue
            if target.exists() and metadata.get("sha256"):
                raise ValueError("A pinned local texture has changed: " + filename)
            with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as tmp:
                temp = Path(tmp.name)
                try:
                    request = urllib.request.Request(metadata["url"], headers={"User-Agent": "CasinoAnomalyAssetImport/2.0"})
                    with urllib.request.urlopen(request, timeout=120) as response:
                        safe_source(response.geturl())
                        total = 0
                        while chunk := response.read(128 * 1024):
                            total += len(chunk)
                            if total > MAX_BYTES:
                                raise ValueError("Texture exceeds 30 MiB")
                            tmp.write(chunk)
                except BaseException:
                    temp.unlink(missing_ok=True)
                    raise
            data = temp.read_bytes()
            if filename.endswith(".jpg") and not data.startswith(bytes((255, 216, 255))):
                temp.unlink(missing_ok=True)
                raise ValueError("Not a JPEG image: " + filename)
            if filename.endswith(".png") and not data.startswith(bytes((137, 80, 78, 71, 13, 10, 26, 10))):
                temp.unlink(missing_ok=True)
                raise ValueError("Not a PNG image: " + filename)
            digest = hashlib.sha256(data).hexdigest()
            if metadata.get("sha256") and digest.lower() != metadata["sha256"].lower():
                temp.unlink(missing_ok=True)
                raise ValueError("Pinned source texture hash mismatch: " + filename)
            if metadata.get("bytes") and len(data) != metadata["bytes"]:
                temp.unlink(missing_ok=True)
                raise ValueError("Pinned source texture size mismatch: " + filename)
            metadata["sha256"] = digest
            metadata["bytes"] = len(data)
            shutil.move(str(temp), str(target))
            updated = True
            print("Downloaded and pinned", filename, len(data), flush=True)
        if updated:
            path.write_text(json.dumps(info, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    try:
        ensure()
    except (OSError, ValueError, KeyError, AssertionError) as exception:
        print("Asset import failed:", exception, file=sys.stderr)
        sys.exit(1)
