#!/usr/bin/env python3
"""One-shot, path-only repository migration. Run on a clean tracked checkout.

No asset decoding, scene regeneration, gameplay edits or save migrations.
The CI candidate is committed locally and verified before pushing to dev.
"""
from pathlib import Path
import hashlib
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = "tools/reorganize_repository.py"
WORKFLOW = ".github/workflows/repository-layout-migration.yml"
DROPS = ("audio_drop", "sketchfab_drop", "tutorial_assets_drop")
SCRIPTS = {
    "casino_atmosphere.gd": "gameplay/casino/casino_atmosphere.gd",
    "hall.gd": "gameplay/casino/hall.gd",
    "model_interior.gd": "gameplay/casino/model_interior.gd",
    "sketchfab_furniture.gd": "gameplay/casino/sketchfab_furniture.gd",
    "player.gd": "gameplay/player.gd",
    "menu.gd": "ui/menu.gd",
}
SCENES = {"main.tscn": "gameplay/casino/main.tscn", "menu.tscn": "ui/menu.tscn"}
DOCS = {
    "EDITOR_IMPORTED_MODELS.md": "docs/EDITOR_IMPORTED_MODELS.md",
    "VOXEL_GI.md": "docs/VOXEL_GI.md",
    "README_INSTALLATION.md": "docs/archive/SILENT_AUDIENCE_INSTALLATION.md",
}
TEXT = {".gd", ".gdshader", ".tscn", ".tres", ".cfg", ".godot", ".json", ".py",
        ".md", ".txt", ".ps1", ".sh", ".cs", ".csproj", ".import", ".yml", ".yaml",
        ".xml", ".ini", ".toml"}
def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)

def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()

def main():
    if git("status", "--porcelain", "--untracked-files=all").strip():
        raise SystemExit("Require a clean checkout before migration")
    tracked = [p.decode("utf-8") for p in git("ls-files", "-z").split(b"\0") if p]
    old = set(tracked)
    if "main.tscn" not in old or "menu.tscn" not in old:
        raise SystemExit("Expected original root scenes; migration is one-shot")
    mapping = SCRIPTS | SCENES | DOCS
    mapping.update({p: "assets/materials/" + p for p in tracked
                    if "/" not in p and p.endswith(".tres")})
    mapping.update({p: "source_assets/" + p for p in DROPS})
    moves = {}
    for p in tracked:
        if p in mapping:
            moves[p] = mapping[p]
        elif p.endswith(".gd.uid") and p[:-4] in SCRIPTS:
            moves[p] = SCRIPTS[p[:-4]] + ".uid"
        elif p.split("/", 1)[0] in DROPS:
            moves[p] = "source_assets/" + p
    if len(set(moves.values())) != len(moves) or set(moves.values()) & old:
        raise SystemExit("Destination collision")
    # Replace full res:// references and repo-root relative paths together,
    # including code literals, documentation, importer configs and tests.
    # Boundaries prevent matching the same name inside existing subfolders.
    # Dot after a filename is allowed only as prose punctuation, not .uid.
    token = re.compile(rb"(?<![A-Za-z0-9_./-])(?:res://)?("
        + b"|".join(re.escape(k.encode()) for k in sorted(mapping, key=len, reverse=True))
        + rb")(?![A-Za-z0-9_-]|\.[A-Za-z0-9_])")
    def rewrite(raw):
        def replace(m):
            prefix = b"res://" if m.group(0).startswith(b"res://") else b""
            return prefix + mapping[m.group(1).decode()].encode()
        out = token.sub(replace, raw)
        # Root-anchored ignore entries are not relative res:// paths.
        return out

    # Existing CI workflows must remain byte-identical. GitHub's token
    # cannot edit workflow files, and no functional workflow references need
    # migration. A historical message mentioning main.tscn is harmless.
    changed = set()
    hashes = {}
    for p in tracked:
        path = ROOT / p
        if p in (SCRIPT, WORKFLOW) or p.startswith(".github/"):
            continue
        if p in moves and path.suffix.lower() not in TEXT:
            hashes[p] = digest(path)
        if path.suffix.lower() not in TEXT and p not in (".gitignore", ".gitattributes"):
            continue
        raw = path.read_bytes()
        out = rewrite(raw)
        if p == ".gitignore":
            for drop in DROPS:
                out = out.replace(("\n/" + drop + "/").encode(),
                                  ("\n/source_assets/" + drop + "/").encode())
        if p == "README.md":
            out = out.replace(b"[Installation information](docs/archive/SILENT_AUDIENCE_INSTALLATION.md)",
                              b"[Installation information](docs/INSTALLATION.md)")
            out = out.replace(b"[Asset credits](ASSET_CREDITS.md)",
                              b"[Asset credits](ASSET_CREDITS.md) \xc2\xb7 [Repository layout](docs/REPOSITORY_LAYOUT.md)")
        if out != raw:
            path.write_bytes(out)
            changed.add(p)
    # Check orphaned sidecar against all original textual references.
    orphan = "casino2_preview.gd.uid"
    removed = set()
    if orphan in old and "casino2_preview.gd" not in old:
        uid = (ROOT / orphan).read_bytes().strip()
        referenced = False
        for p in tracked:
            if p == orphan or p in (SCRIPT, WORKFLOW):
                continue
            path = ROOT / p
            if path.suffix.lower() in TEXT:
                raw = path.read_bytes()
                if uid in raw or b"casino2_preview.gd" in raw:
                    referenced = True
                    break
        if not referenced and uid.startswith(b"uid://"):
            (ROOT / orphan).unlink()
            removed.add(orphan)
    for p, dest in moves.items():
        source, target = ROOT / p, ROOT / dest
        target.parent.mkdir(parents=True, exist_ok=True)
        source.rename(target)
    for d in DROPS:
        for directory in sorted((ROOT / d).rglob("*"), reverse=True):
            if directory.is_dir():
                directory.rmdir()
        (ROOT / d).rmdir()
    for p, sha in hashes.items():
        if digest(ROOT / moves[p]) != sha:
            raise SystemExit("Moved non-text source changed: " + p)
    expected = (old - set(moves) - removed) | set(moves.values())
    for p in expected:
        if not (ROOT / p).is_file():
            raise SystemExit("Missing tracked path: " + p)
    for p in moves:
        if (ROOT / p).exists():
            raise SystemExit("Old path still exists: " + p)
    # Verify no stale root res:// path remains, including path comparisons
    # in the scene loader, pause menu, QA suites and Godot editor plugins.
    stale = re.compile(rb"res://(" + b"|".join(re.escape(k.encode()) for k in mapping)
                       + rb")(?![A-Za-z0-9_.-])")
    for p in expected:
        path = ROOT / p
        if p not in (SCRIPT, WORKFLOW) and path.suffix.lower() in TEXT:
            hit = stale.search(path.read_bytes())
            if hit:
                raise SystemExit("Stale resource reference: " + p + ": " + repr(hit.group(0)))
    # Baked geometry and PBR model files were not moved or modified. Preserve
    # the exact scene body: only path strings may change, never transforms.
    print("Repository migration:", len(moves), "moved paths,", len(changed),
          "path-updated files,", len(removed), "unreferenced UID sidecars removed")
    print("REPOSITORY_LAYOUT_MIGRATION_PASS")

if __name__ == "__main__":
    main()
