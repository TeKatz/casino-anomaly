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


## Human-scale proportions and facial-only talking (November 2026)

Sketchfab's model contains nested FBX-to-glTF axis/scale corrections.
Godot correctly imports the standing rig, but the character looks too
small and narrow beside the counter and oversized intro door. The visual
model root now uses editor-adjustable proportions (1.95, 1.24, 2.1),
bringing the animated crown/head to approximately adult height without
moving the table or affecting the first-room gameplay.

The source "Rig|idle" glTF clip has 97 channels; its
"Rig|cycle_talking" clip has just 11 (lips, tongue, jaw). Godot **imports
both as 84 tracks**, filling otherwise unanimated body bones with
rest-pose channels. Playing the imported talking clip directly, or
masking all 84 of its tracks, forces the arms to a T-pose. The
AnimationTree Blend2 filter now **whitelists jaw, upper/lower lips
and tongue only**, preserving full-body idle without interruption.
CI tests the facial mask against every imported track and compares
hand positions before and after opening a conversation.

The CI intro QA verifies actual animated skeletal landmarks and checks
that the hand positions do not jump when the facial overlay is active.
Unskinned mesh bounding boxes are misleading for this particular asset
because its bind-pose axes differ from the displayed rig.
