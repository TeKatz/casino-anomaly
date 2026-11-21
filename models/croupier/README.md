# Business Man — Croupier model asset

The intended intro NPC is **Business Man – Low Polygon game character**
by **manoeldarochadeoliveira**, licensed **CC BY 4.0**.

- Source: https://sketchfab.com/3d-models/business-man-low-polygon-game-character-b6f6740f883b4749abac47af0045a9dd
- License: https://creativecommons.org/licenses/by/4.0/
- SHA-256 of original user-provided ZIP: 6e5e214f579846d387fdcb6d20cd4448e4b518b0bb87b7cfb1f2e97ca676ef54

Place the **original, unchanged** Sketchfab ZIP at
sketchfab_drop/business_man.zip. The development workflow runs
python tools/import_croupier_asset.py before the Godot import; it checks
the exact archive against its checksum, the animation names, and license.
It extracts scene.gltf, scene.bin and the source textures into this directory.

After extraction Godot loads the model under CroupierStation/CharacterPivot/ModelAnchor.
If the archive has not yet been provided the lightweight proxy remains.
No character is downloaded at runtime. The model's transform is adjustable
on the CroupierStation node; see gameplay/croupier_station.gd.


## Orientation regression guard

The imported scene is already Y-up and its front faces the counter customer
(+Z). Keep CroupierStation.imported_model_rotation at Vector3.ZERO.
Do not infer pose from the static mesh AABB; the original bug made its
Skeleton3D lie horizontally even though the bind-pose mesh bounds looked
upright. The intro QA checks animated skeleton landmarks (head, feet, face)
and requires a human-height upright character facing the player.


## Body proportions (November 2026)

The original model, once imported with the FBX rig, appeared stretched
vertically and paper-thin horizontally in the actual Godot room despite
passing the bone-pose tests. The croupier script applies an outer-root
width/depth correction of (2.35, 1.0, 2.6), preserving height, textures,
skeleton and original animation files. This is adjustable in the scene's
inspector for later art direction. An additional QA check measures imported
mesh AABBs in *world units* to detect regressions in visual proportions.
