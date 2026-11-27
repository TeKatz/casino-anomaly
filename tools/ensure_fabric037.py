#!/usr/bin/env python3
"""Install Fabric037 from ambientCG's public CC0 package, byte-for-byte.

The user provided the 2K JPG archive for this exact material. All SHA-256
checksums below were measured against that archive, not inferred.
No proprietary binaries, Blender scenes or USD assets are distributed.
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
BASE = ROOT / "assets" / "fabric037"
INFO = BASE / "ambient_source.json"
MAX_ZIP_BYTES = 42_000_000
HEADERS = {"User-Agent": "CasinoAnomalyAssetImport/2.0"}

def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def ensure() -> None:
    data = json.loads(INFO.read_text("utf-8"))
    if data.get("license") != "CC0-1.0" or data.get("asset") != "Fabric037":
        raise ValueError("Unexpected Fabric037 license or asset ID")
    targets = data["maps"]
    if all(
        (BASE / name).is_file() and (BASE / name).stat().st_size == m["bytes"]
        and sha256((BASE / name).read_bytes()) == m["sha256"]
        for name,m in targets.items()
    ):
        print("Verified ambientCG Fabric037 against user-provided SHA-256 hashes",flush=True)
        return

    url=data["download"]
    req=urllib.request.Request(url,headers=HEADERS)
    with urllib.request.urlopen(req,timeout=120) as response:
        final=urlsplit(response.geturl())
        if final.scheme!="https" or final.hostname not in (
            "acg-download.struffelproductions.com",
            "ambientcg.com",
        ):
            raise ValueError("Unexpected ambientCG download host: "+str(final.hostname))
        chunks=[]
        size=0
        while True:
            chunk=response.read(256*1024)
            if not chunk:
                break
            size+=len(chunk)
            if size>MAX_ZIP_BYTES:
                raise ValueError("Unexpected Fabric037 download size")
            chunks.append(chunk)
    archive=b"".join(chunks)
    if sha256(archive)!=data["uploadedZipSha256"]:
        raise ValueError("ambientCG Fabric037 ZIP differs from the provided original")
    with zipfile.ZipFile(io.BytesIO(archive)) as z:
        if len(z.namelist()) > 32:
            raise ValueError("Unexpected Fabric037 archive contents")
        for name,metadata in targets.items():
            payload=z.read(name)
            if len(payload)!=metadata["bytes"] or sha256(payload)!=metadata["sha256"]:
                raise ValueError("Fabric037 contained mismatched PBR image: "+name)
            if not payload.startswith(b"\xff\xd8\xff"):
                raise ValueError("Invalid Fabric037 JPEG: "+name)
            target=BASE/name
            target.parent.mkdir(parents=True,exist_ok=True)
            tmp=target.with_suffix(".download")
            tmp.write_bytes(payload)
            os.replace(tmp,target)
            print("Installed ambientCG image:",name,len(payload),flush=True)
    print("Fabric037 source archive and three PBR maps verified",flush=True)

if __name__=="__main__":
    try:
        ensure()
    except Exception as e:
        print("ambientCG Fabric037 import FAILED:",str(e),file=sys.stderr)
        sys.exit(1)
