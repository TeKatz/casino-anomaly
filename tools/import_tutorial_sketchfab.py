#!/usr/bin/env python3
"""Optional original glTF import; no scraping or unauthenticated downloads."""
import json
import shutil
import zipfile
from pathlib import Path, PurePosixPath
ROOT=Path(__file__).resolve().parents[1]
DROP=ROOT/"tutorial_assets_drop"
OUT=ROOT/"models"/"tutorial_user"
catalog=json.loads((DROP/"catalog.json").read_text("utf-8"))

def install(zip_path, slug):
    # GitHub accepts repository files up to 100 MiB. The uploaded Books
    # archive is 25,711,884 bytes, so the older 24 MiB limit was wrong.
    if zip_path.stat().st_size > 80*1024*1024:
        raise ValueError(f"{slug} ZIP exceeds 80 MiB")
    with zipfile.ZipFile(zip_path) as archive:
        members=[p for p in archive.infolist() if not p.is_dir()]
        if sum(p.file_size for p in members)>160*1024*1024:
            raise ValueError(f"{slug}: expansion limit exceeded")
        names={}
        for item in members:
            p=PurePosixPath(item.filename)
            if (item.filename.startswith("/") or "\\" in item.filename
                    or ".." in p.parts or item.file_size>80*1024*1024):
                raise ValueError(f"{slug}: unsafe ZIP entry {item.filename}")
            names[p.as_posix()]=item
        candidates=[p for p in names if PurePosixPath(p).name in ("scene.gltf","scene.glb")]
        if not candidates:
            raise ValueError(f"{slug}: original Sketchfab glTF archive missing scene.gltf/glb")
        main=min(candidates,key=lambda p: (not p.endswith(".gltf"),len(p)))
        base=PurePosixPath(main).parent
        stage=OUT/(slug+"_temporary")
        dest=OUT/slug
        if stage.exists():
            shutil.rmtree(stage)
        stage.mkdir(parents=True)
        try:
            for path,info in names.items():
                p=PurePosixPath(path)
                try:
                    rel=p.relative_to(base) if str(base)!="." else p
                except ValueError:
                    continue
                target=stage.joinpath(*rel.parts)
                target.parent.mkdir(parents=True,exist_ok=True)
                with archive.open(info) as inp, target.open("wb") as out:
                    shutil.copyfileobj(inp,out)
            main_file=stage/PurePosixPath(main).name
            if main_file.suffix==".gltf":
                doc=json.loads(main_file.read_text("utf-8"))
                for item in [*doc.get("buffers",[]),*doc.get("images",[])]:
                    uri=item.get("uri","")
                    if not uri or uri.startswith("data:"):
                        continue
                    p=PurePosixPath(uri)
                    if ".." in p.parts or uri.startswith("/") or not (stage/p).is_file():
                        raise ValueError(f"{slug}: missing/unsafe GLTF dependency {uri}")
            if dest.exists():
                # The archives contain source models/textures, not Godot's
                # adjacent .import sidecars. Preserve settings and stable UIDs
                # for every source file that is still present in the archive.
                # Without this, GitHub Actions deletes the committed sidecars
                # and Godot regenerates them on every local editor startup.
                for source in stage.rglob("*"):
                    if not source.is_file() or source.suffix == ".import":
                        continue
                    relative = source.relative_to(stage)
                    previous_sidecar = dest / (str(relative) + ".import")
                    if previous_sidecar.is_file():
                        new_sidecar = stage / (str(relative) + ".import")
                        shutil.copy2(previous_sidecar, new_sidecar)
                shutil.rmtree(dest)
            stage.rename(dest)
        finally:
            if stage.exists():
                shutil.rmtree(stage)
    print("Imported user-provided Sketchfab model:", slug,
          "| scene:", main,
          "| archive entries:", len(members),
          "| model bytes:", zip_path.stat().st_size)

def main():
    imported=0
    for row in catalog["models"]:
        slug=row["id"]
        source=DROP/(slug+".zip")
        if source.exists():
            if slug=="books_with_magnifier" and not (DROP/"books_with_magnifier.license.txt").is_file():
                raise ValueError("Books license must be verified and recorded in books_with_magnifier.license.txt")
            install(source,slug)
            imported+=1
    print(f"Sketchfab tutorial set: {imported}/4 imported. Missing models keep existing props.")

if __name__=="__main__":
    main()
