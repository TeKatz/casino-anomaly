# Oxygen Backrooms packs (CC0)

These third-party assets are authored by **Oxygen**, not by Casino Anomaly. Both
packs are published as **Creative Commons Zero v1.0 Universal (CC0-1.0)**.
Attribution is optional; source links are preserved.

- Vol. 1 (modular rooms): https://oxygen3d.itch.io/game-ready-backrooms-asset-pack-vol-1
- Vol. 2 (room props): https://oxygen3d.itch.io/game-ready-backrooms-asset-pack-vol-2
- License: https://creativecommons.org/publicdomain/zero/1.0/

## Godot 4.5 assets

- `vol1/backrooms.fbx` + `vol1/backrooms.png`: modular room meshes and atlas.
- `vol2/Backrooms_Vol2_1k.glb`: room props with embedded atlas. Individual
  nodes can be edited by instancing the imported scene and enabling
  **Editable Children**.
- `sources/*.zip`: untouched original Blender, OBJ, FBX and texture archives
  retained for future authoring.

All the game-ready assets are checked into the repository; runtime downloads
are not required. The import script verifies the exact source ZIP SHA256
before extraction. No gameplay scenes, lighting, player movement, or
collisions are changed by this asset-only import.

### Source ZIP SHA256

```
backrooms.zip         b18663967868271c80bc1cea5d3c36351e19641a0bed5739dd69bf62c7c80a84
Backrooms_Vol2_1k.zip 30ac9b69152feb9db7befd2fbdd61de9fcd9b94726f56794496878fb5635a1aa
```
