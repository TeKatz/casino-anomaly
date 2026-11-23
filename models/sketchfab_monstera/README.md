# Giora Monstera replacement — source model from user upload

Source: https://sketchfab.com/3d-models/monstera-deliciosa-potted-mid-century-plant-1ab9bf841df04c07b1819be596327629
Author: Giora (https://sketchfab.com/ChubbyPanda)
License: CC BY 4.0; retain the author's supplied `license.txt`.

The original archive contains 4 distinct glTF meshes and nine PBR textures.
The optimized asset pack retains every source mesh and UV and reduces 4K
textures to 256–1024px. No replacement meshes or images are generated.

The Godot scene uses `gameplay/monstera_import.gd` on the six **existing**
`Decor/Plant_00` through `Decor/Plant_05` nodes. Importing the optimized
source glTF automatically hides their old procedural visuals without changing
those parents, so the plant anomalies remain functional.

## Install original model data

Extract the provided `casino_anomaly_monstera_assets.zip` at the PROJECT
ROOT. After extraction, the file should be
`res://models/sketchfab_monstera/scene.gltf`, accompanied by `scene.bin`,
`license.txt` and its `textures/` directory.

Godot will import these resources on the next editor startup. Select the
`Plant_XX` wrapper to adjust position and rotation in the Godot editor.
The glTF model is a real three-dimensional PBR asset, not a sprite.

The gameplay uses a feature-detecting loader so development builds without
the optional model data keep the legacy decorations rather than breaking.
This source archive **must be added to the project before releasing a game
build that claims to include the Giora Monstera**.
