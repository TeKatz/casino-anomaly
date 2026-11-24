"""Read-only rendering asset inventory. Python stdlib only; no asset rewrites."""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
from collections import defaultdict
from pathlib import Path


def gltf_document(path: Path) -> dict:
    if path.suffix.lower() == ".gltf":
        return json.loads(path.read_text(encoding="utf-8-sig"))
    with path.open("rb") as stream:
        magic, version, length = struct.unpack("<4sII", stream.read(12))
        size, kind = struct.unpack("<I4s", stream.read(8))
        if magic != b"glTF" or version != 2 or kind != b"JSON" or size > length - 20:
            raise ValueError("Invalid GLB JSON header")
        return json.loads(stream.read(size).decode("utf-8").rstrip("\x00 "))


def mesh_metrics(doc: dict) -> dict:
    accessors = doc.get("accessors", [])
    meshes = doc.get("meshes", [])
    triangles = []
    surfaces = 0
    for mesh in meshes:
        count = 0
        for primitive in mesh.get("primitives", []):
            surfaces += 1
            index = primitive.get("indices", primitive.get("attributes", {}).get("POSITION"))
            if index is None:
                continue
            vertices = accessors[index]["count"]
            mode = primitive.get("mode", 4)
            if mode == 4:
                count += vertices // 3
            elif mode in (5, 6):
                count += max(0, vertices - 2)
        triangles.append(count)
    instances = [node["mesh"] for node in doc.get("nodes", []) if "mesh" in node]
    return {
        "source_triangles": sum(triangles),
        "mesh_node_triangles": sum(triangles[i] for i in instances),
        "mesh_nodes": len(instances),
        "surfaces": surfaces,
        "materials": len(doc.get("materials", [])),
        "textures": len(doc.get("textures", [])),
    }


def image_dimensions(path: Path) -> tuple[int, int] | None:
    with path.open("rb") as stream:
        first = stream.read(24)
        if first[:8] == b"\x89PNG\r\n\x1a\n" and first[12:16] == b"IHDR":
            return struct.unpack(">II", first[16:24])
        if first[:2] != b"\xff\xd8":
            return None
        stream.seek(2)
        while True:
            byte = stream.read(1)
            if not byte:
                return None
            if byte != b"\xff":
                continue
            marker = stream.read(1)
            while marker == b"\xff":
                marker = stream.read(1)
            if not marker or marker in (b"\xd9", b"\xda"):
                return None
            code = marker[0]
            if code == 0 or code == 1 or 0xD0 <= code <= 0xD8:
                continue
            raw = stream.read(2)
            if len(raw) != 2:
                return None
            length = struct.unpack(">H", raw)[0]
            if length < 2:
                return None
            if code in {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}:
                payload = stream.read(5)
                if len(payload) != 5:
                    return None
                height, width = struct.unpack(">HH", payload[1:])
                return width, height
            stream.seek(length - 2, 1)


def import_options(path: Path) -> dict:
    sidecar = path.with_name(path.name + ".import")
    if not sidecar.is_file():
        return {}
    result = {}
    for line in sidecar.read_text(encoding="utf-8-sig").splitlines():
        key, sep, value = line.partition("=")
        if sep and key in {"meshes/generate_lods", "meshes/create_shadow_meshes",
                           "compress/mode", "compress/normal_map", "mipmaps/generate",
                           "process/size_limit"}:
            result[key] = value
    return result


def audit(root: Path) -> dict:
    meshes, textures, errors = [], [], []
    duplicates = defaultdict(list)
    for directory in ("models", "assets"):
        for path in sorted((root / directory).rglob("*")):
            if not path.is_file():
                continue
            name = path.relative_to(root).as_posix()
            suffix = path.suffix.lower()
            try:
                if suffix in (".gltf", ".glb"):
                    meshes.append({"path": name, **mesh_metrics(gltf_document(path)),
                                   "import": import_options(path)})
                elif suffix in (".jpg", ".jpeg", ".png"):
                    digest = hashlib.sha256()
                    with path.open("rb") as stream:
                        for block in iter(lambda: stream.read(1024 * 1024), b""):
                            digest.update(block)
                    duplicates[digest.hexdigest()].append(name)
                    dimensions = image_dimensions(path)
                    textures.append({"path": name, "bytes": path.stat().st_size,
                                     "dimensions": dimensions, "import": import_options(path)})
            except (OSError, ValueError, KeyError, IndexError, TypeError, struct.error) as exc:
                errors.append({"path": name, "error": str(exc)})
    meshes.sort(key=lambda entry: entry["source_triangles"], reverse=True)
    textures.sort(key=lambda entry: entry["bytes"], reverse=True)
    return {
        "meshes": meshes,
        "textures": textures,
        "identical_source_textures": [paths for paths in duplicates.values() if len(paths) > 1],
        "errors": errors,
        "notes": [
            "Source triangle counts, not imported LOD or frame draw calls.",
            "Mesh-node totals count every mesh-bearing glTF node, not scene placements.",
            "Source byte sizes are not VRAM sizes. Missing sidecars are reported as empty.",
            "Run after asset extraction for ZIP-only assets. No files are changed.",
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    print(json.dumps(audit(args.root.resolve()), indent=2, ensure_ascii=True))


if __name__ == "__main__":
    main()
