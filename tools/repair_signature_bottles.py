#!/usr/bin/env python3
"""Migrate invalid Godot instance patches to persistent, editable mesh nodes.

The signature bottle templates are intentionally script-only. Historical editor
saves wrote 664 '[node ... index=...]' patches for transient @tool meshes.
Those nodes do not exist in the template, so Godot reports them as vanished.

This byte-preserving migration changes only those node headers; all existing
mesh subresources, materials, transforms, nesting and bottle instances remain.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

SCENE = Path(__file__).resolve().parents[1] / "main.tscn"
PATCH = re.compile(
    rb'(?m)^\[node name="(?P<name>[^"\r\n]+)" '
    rb'parent="(?P<parent>CornerBar/Signature_[^"\r\n]+)" '
    rb'index="\d+"\](?=\r?$)'
)
OWNED = re.compile(
    rb'(?m)^\[node name="[^"\r\n]+" '
    rb'type="(?:MeshInstance3D|MultiMeshInstance3D)" '
    rb'parent="CornerBar/Signature_[^"\r\n]+"\](?=\r?$)'
)
EDITABLE = re.compile(rb'(?m)^\[editable path="([^"\r\n]+)"\](?=\r?$)')
MESH = re.compile(rb'(?m)^mesh = ')
MULTIMESH = re.compile(rb'(?m)^multimesh = ')


def migrate(data: bytes) -> tuple[bytes, int]:
    """Return modified bytes without changing any geometry or other sections."""
    editable = set(EDITABLE.findall(data))
    count = 0

    def replace(match: re.Match[bytes]) -> bytes:
        nonlocal count
        name, parent = match.group("name"), match.group("parent")
        if parent not in editable:
            raise ValueError(f"Target instance is not editable: {parent!r}")
        following = data.find(b"\n[", match.end())
        body = data[match.end(): following if following >= 0 else len(data)]
        mesh, multi = bool(MESH.search(body)), bool(MULTIMESH.search(body))
        if mesh == multi:
            raise ValueError(f"Unknown or ambiguous geometry type for {name!r}")
        kind = b"MultiMeshInstance3D" if multi else b"MeshInstance3D"
        count += 1
        return b'[node name="' + name + b'" type="' + kind + b'" parent="' + parent + b'"]'

    return PATCH.sub(replace, data), count


def verify(data: bytes) -> int:
    if PATCH.search(data):
        raise ValueError("Stale signature bottle instance override remains")
    total = len(OWNED.findall(data))
    if total < 600:
        raise ValueError(f"Expected saved bottle meshes, found only {total}")
    if b'[node name="Signature_3_13_montevale"' not in data:
        raise ValueError("Original author-placed signature bottles are missing")
    return total


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--apply", action="store_true", help="Migrate safe patches")
    group.add_argument("--check", action="store_true", help="Validate saved meshes")
    args = parser.parse_args()
    before = SCENE.read_bytes()
    if args.apply:
        after, converted = migrate(before)
        owned = verify(after)
        if converted:
            if converted < 600:
                raise ValueError(f"Only {converted} patches matched; refusing partial migration")
            SCENE.write_bytes(after)
        print(f"Signature bottle migration: {converted} converted, {owned} persisted meshes")
    else:
        print(f"Signature bottle scene valid: {verify(before)} persisted meshes")


if __name__ == "__main__":
    main()
