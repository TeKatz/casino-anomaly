#!/usr/bin/env python3
"""Import exactly ten user-selected CC0 Poly Haven glTF models with dependencies.

The official API supplies the glTF file, a binary buffer and the texture maps
listed under include. All downloads are checked against API MD5/size and locally
pinned SHA-256 in models/asset_index.json. Existing pinned files are never
silently replaced. Paths and domains are validated before writing.
"""
import hashlib
import json
import os
import posixpath
import sys
import tempfile
import time
import urllib.request
from pathlib import Path, PurePosixPath
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "models"
CATALOG = MODELS / "catalog.json"
INDEX = MODELS / "asset_index.json"
HEADERS = {"User-Agent": "CasinoAnomalyModelImporter/1.0"}
MAX_FILE = 35_000_000
MAX_TOTAL = 130_000_000


def trusted_url(url: str, api: bool = False) -> None:
    p = urlsplit(url)
    expected = "api.polyhaven.com" if api else "dl.polyhaven.org"
    if p.scheme != "https" or p.hostname != expected or p.port not in (None, 443):
        raise ValueError("Unexpected source: " + url)
    if not api and not p.path.startswith("/file/ph-assets/Models/"):
        raise ValueError("Unexpected model location: " + url)


def load_json(url: str) -> dict:
    trusted_url(url, api=True)
    request = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(request, timeout=35) as response:
        trusted_url(response.geturl(), api=True)
        return json.load(response)


def relative_file(relative: str) -> Path:
    p = PurePosixPath(relative)
    if p.is_absolute() or not p.parts or any(part in (".", "..") for part in p.parts):
        raise ValueError("Unsafe model dependency path: " + relative)
    return Path(*p.parts)


def sha_file(path: Path) -> str:
    with path.open("rb") as f:
        return hashlib.file_digest(f, "sha256").hexdigest()


def file_valid(path: Path, item: dict) -> bool:
    return (
        path.is_file()
        and path.stat().st_size == int(item["bytes"])
        and sha_file(path) == item["sha256"]
    )


def download(url: str, path: Path, expected: dict) -> dict:
    trusted_url(url)
    if path.exists() and expected.get("sha256") and file_valid(path, expected):
        return expected
    if path.exists() and expected.get("sha256"):
        raise ValueError("Pinned asset changed locally: " + str(path))
    if path.exists() and not expected.get("sha256"):
        raise ValueError("Unpinned file already exists: " + str(path))

    path.parent.mkdir(parents=True, exist_ok=True)
    for attempt in range(3):
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as out:
                temporary = Path(out.name)
                request = urllib.request.Request(url, headers=HEADERS)
                with urllib.request.urlopen(request, timeout=110) as response:
                    trusted_url(response.geturl())
                    size = 0
                    digest_md5 = hashlib.md5()
                    digest_sha = hashlib.sha256()
                    while True:
                        chunk = response.read(256 * 1024)
                        if not chunk:
                            break
                        size += len(chunk)
                        if size > MAX_FILE:
                            raise ValueError("Unreasonably large source file: " + url)
                        digest_md5.update(chunk)
                        digest_sha.update(chunk)
                        out.write(chunk)
            if expected.get("apiSize") is not None and size != expected["apiSize"]:
                raise ValueError("Size differs from Poly Haven API: " + path.name)
            if expected.get("apiMd5") and digest_md5.hexdigest() != expected["apiMd5"]:
                raise ValueError("MD5 differs from Poly Haven API: " + path.name)
            if expected.get("sha256") and digest_sha.hexdigest() != expected["sha256"]:
                raise ValueError("Pinned SHA-256 mismatch: " + path.name)
            if expected.get("bytes") and size != expected["bytes"]:
                raise ValueError("Pinned file size mismatch: " + path.name)
            os.replace(temporary, path)
            print("  Verified download:", path.relative_to(ROOT), size, flush=True)
            return {
                "url": url, "apiMd5": expected.get("apiMd5"),
                "apiSize": expected.get("apiSize"), "bytes": size,
                "sha256": digest_sha.hexdigest()
            }
        except (OSError, ValueError) as exc:
            if temporary is not None:
                temporary.unlink(missing_ok=True)
            if attempt == 2 or isinstance(exc, ValueError):
                raise
            print("  Retrying", path.name, str(exc), flush=True)
            time.sleep(2 * (attempt + 1))
    raise AssertionError("unreachable")


def inspect_gltf(gltf_path: Path, base: Path) -> None:
    asset = json.loads(gltf_path.read_text(encoding="utf-8"))
    if str(asset.get("asset", {}).get("version")) != "2.0":
        raise ValueError("Not a glTF 2.0 asset: " + gltf_path.name)
    for resource in asset.get("buffers", []) + asset.get("images", []):
        path = resource.get("uri")
        if path and not path.startswith("data:"):
            dependent = base / relative_file(path)
            if not dependent.is_file():
                raise ValueError("Missing glTF dependency: " + str(dependent))


def main() -> None:
    spec = json.loads(CATALOG.read_text(encoding="utf-8"))
    if spec.get("schemaVersion") != 1 or spec.get("license") != "CC0-1.0":
        raise ValueError("Unexpected model catalog version or license")
    existing = json.loads(INDEX.read_text(encoding="utf-8")) if INDEX.exists() else {"assets": {}}
    assets = existing.setdefault("assets", {})
    total = 0
    for item in spec["models"]:
        identifier = item["id"]
        if "/" in identifier or "\\" in identifier or identifier in (".", ".."):
            raise ValueError("Unsafe asset ID: " + identifier)
        folder = MODELS / identifier
        base = "https://api.polyhaven.com/files/" + identifier
        # A fully pinned asset can be validated offline on subsequent CI builds.
        pinned = assets.get(identifier)
        if pinned and all(
            file_valid(folder / relative_file(path), details)
            for path, details in pinned["files"].items()
        ):
            for details in pinned["files"].values():
                total += details["bytes"]
            print("All pinned files valid:", identifier, flush=True)
            continue

        files = load_json(base)
        variants = files.get("gltf", {})
        resolution = item.get("resolution", spec["resolution"])
        choice = variants.get(resolution, {})
        main_file = choice.get("gltf")
        if not main_file:
            raise ValueError("No requested " + resolution + " glTF: " + identifier)
        main_name = PurePosixPath(urlsplit(main_file["url"]).path).name
        sources = {main_name: main_file, **main_file.get("include", {})}
        if not all(isinstance(path, str) for path in sources):
            raise ValueError("Invalid includes for " + identifier)
        manifest = {"sourcePage": "https://polyhaven.com/a/" + identifier,
                    "resolution": resolution, "entrypoint": main_name, "files": {}}
        for relative, remote in sources.items():
            subpath = relative_file(relative)
            target = folder / subpath
            prev = (pinned or {}).get("files", {}).get(relative, {})
            check = {
                "apiMd5": remote.get("md5"), "apiSize": remote.get("size"),
                **({"sha256": prev["sha256"], "bytes": prev["bytes"]} if "sha256" in prev else {})
            }
            result = download(remote["url"], target, check)
            manifest["files"][relative] = result
            total += result["bytes"]
            if total > MAX_TOTAL:
                raise ValueError("Total source asset budget exceeded 130 MB")
        inspect_gltf(folder / main_name, folder)
        assets[identifier] = manifest
        print("Imported model:", identifier, len(sources), "files", flush=True)

    # Stable ordering and immutable checksums are committed with asset binaries.
    INDEX.write_text(json.dumps(existing, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("All", len(spec["models"]), "Poly Haven models verified:", round(total / 1e6, 2), "MB", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("Model import FAILED:", str(error), file=sys.stderr)
        raise
