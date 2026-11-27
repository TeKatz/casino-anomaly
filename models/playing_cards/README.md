# Separated playing cards for Casino Anomaly

Source model: **Playing Cards** by **jdastine**.
Original: https://sketchfab.com/3d-models/playing-cards-2dd7c45bf68a4ce3bf63c995b1bf12bf

The source ZIP contains 52 separate pCube card objects with three actual 3D surfaces each (edge / front / back), so these glTF files are extracted meshes rather than replacement quads. All 52 individual glTF scenes use shared `geometry.bin`, `faces_atlas.jpg` and `card_back.jpg`. DO NOT move individual cards out of this folder without their shared dependencies.

Original scene: `card_00.gltf` through `card_51.gltf` (material mapping in `manifest.json`).

Each card has original dimensions 0.50 × 0.80 source units; the Casino Anomaly tables scale it to 0.12 (about 6 × 9.6 cm). Table cards are instanced as editable scene nodes.

## Attribution / licensing

A third-party credits PDF identifies this jdastine model as **CC BY 4.0** (https://skfb.ly/o9M9G), while the included Sketchfab `license.txt` is a generic liability statement and the embedded glTF metadata says `COPYRIGHT TO jdastine`. Preserve attribution. Verify directly with the source page/author before distributing the source or shipping publicly if there is any doubt. All original ZIP textures were downsampled, and cards were isolated as independent glTF resources.
