# Backrooms labyrinth — chosen sketch 02

Open `res://backrooms/backrooms_labyrinth.tscn` in Godot 4.5.1. This standalone
scene is **not** yet linked to the casino anomaly rotation or player controller.
F6 renders the fixed entrance preview camera. Use the 3D editor to inspect the
whole scene; there is no runtime layout generation.

## Geometry and editing

The chosen second sketch in the second series was traced on a 1248 px normalized
canvas at 32 px/m. `sketch_02_layout.json` preserves the traced coordinates
and original wall openings for all 43 wall segments. The outside dimensions
between wall centerlines are 33.0625 × 26.5 m, with 3 m interior height and
0.40 m walls. Entrance left, exit right. Both left entrance rooms, the central
room, and all other reachable corridors are preserved; the small lower-left
rectangle was entirely closed in the sketch and is intentionally inaccessible.
Do not add a door there unless deliberately revising the selected layout.

- `Architecture/Walls`: every named wall is a saved StaticBody3D with its
  own BoxMesh and BoxShape3D. Select a wall body to move it. Change its
  **Dimensions** inspector property to resize the visual and collision
  together; avoid editing only the mesh or scaling the collision child.
- `Architecture/Floor` and `Architecture/Ceiling`: saved editable bodies.
- `Lighting/CeilingFixtures`: 17 individually editable fixtures (14 active,
  3 off), each with housing, panel and a downward SpotLight3D. To change an
  off fixture, enable Downlight visibility and assign the lit panel material.
- `Markers/Entrance` and `Markers/Exit`: entry and exit positions for the
  future player/controller.
- The three native StandardMaterial3D resources tile the original Oxygen
  clean wallpaper, carpet and ceiling tile texture regions at 3 m per repeat.
  Original atlas remains untouched; no new texture source is used.

## Lighting and VoxelGI

The standalone WorldEnvironment uses low ambient light and restrained warm
ceiling spots with shadows. Actual brightness should be tuned in the GPU-backed
editor; the headless QA checks scene structure, not rendered exposure.

A scene-owned 128-subdivision `Lighting/BackroomsVoxelGI` covers the entire
layout. Its data has not been baked by headless CI. Direct lights work without
GI. Open this scene with Forward+, then select **Project > Tools > Casino:
VoxelGI neu backen...** and confirm. The editor detects the active scene,
saves it and launches a separate GPU-backed process. It writes only
`res://backrooms/backrooms_voxel_gi.res` and reloads the completed bake in the
open scene. Subsequent editor/runtime opens load the same external resource
when present; fresh checkouts without it keep direct lights. No geometry is
generated or rewritten by the baker. Existing casino wing resources are untouched.
Re-bake after changes to walls or light fixtures. The first bake uses a dim
interior GI preset; subsequent bakes retain the previous data settings.
Commit the baked .res alongside any intentional scene edits, not .godot caches.
Console fallback (no --headless):
`Godot_v4.5.1-stable_win64_console.exe --path . --rendering-method forward_plus --script res://tools/bake_backrooms_voxel_gi.gd`.

No player, flashlight, sound, enemies, props, anomaly logic, or main-scene
changes are included in this blockout.
