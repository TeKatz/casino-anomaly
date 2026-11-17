#!/usr/bin/env python3
"""Download the original Poly Haven images only when missing; enforce pinned hashes."""
import hashlib
import json
import shutil
import sys
import tempfile
import urllib.request
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / "assets" / "oak_wood_planks"
METADATA = FOLDER / "source.json"
MAX_BYTES = 30 * 1024 * 1024


def ensure() -> None:
    manifest = json.loads(METADATA.read_text(encoding="utf-8"))
    assert manifest["asset"] == "oak_wood_planks"
    assert manifest["license"] == "CC0-1.0"
    for filename, file in manifest["maps"].items():
        if "/" in filename or "\\" in filename:
            raise ValueError("Unsafe filename")
        url = urlsplit(file["url"])
        if url.scheme != "https" or url.hostname != "dl.polyhaven.org" or url.port not in (None, 443):
            raise ValueError("Unexpected source domain")
        target = FOLDER / filename
        if target.exists() and valid(target, file):
            print("Verified", filename)
            continue
        with tempfile.NamedTemporaryFile(dir=FOLDER, delete=False) as tmp:
            temporary = Path(tmp.name)
            try:
                request = urllib.request.Request(file["url"], headers={"User-Agent": "CasinoAnomalyAssetImport/1.0"})
                with urllib.request.urlopen(request, timeout=90) as response:
                    if urlsplit(response.geturl()).hostname != "dl.polyhaven.org":
                        raise ValueError("Unexpected redirect domain")
                    total = 0
                    while chunk := response.read(128 * 1024):
                        total += len(chunk)
                        if total > MAX_BYTES:
                            raise ValueError("Texture exceeds 30 MiB")
                        tmp.write(chunk)
            except BaseException:
                temporary.unlink(missing_ok=True)
                raise
        if not valid(temporary, file):
            temporary.unlink(missing_ok=True)
            raise ValueError("Source texture checksum mismatch: " + filename)
        shutil.move(str(temporary), str(target))
        print("Downloaded and verified", filename)


def valid(path: Path, info: dict) -> bool:
    if path.stat().st_size != info["bytes"]:
        return False
    with path.open("rb") as handle:
        digest = hashlib.file_digest(handle, "sha256").hexdigest()
    return digest.lower() == info["sha256"].lower()


if __name__ == "__main__":
    try:
        ensure()
    except (OSError, ValueError, KeyError, AssertionError) as exc:
        print("Asset import failed:", exc, file=sys.stderr)
        sys.exit(1)
