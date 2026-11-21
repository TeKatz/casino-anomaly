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


## Intro-room body collision and final player-facing size pass

The croupier is a stationary character, so the station scene includes a
separate **StaticBody3D/CapsuleShape3D** behind the counter. Its center is
(0, 0.86, -0.39) in station coordinates, with radius 0.38 m and height
1.70 m. This capsule blocks players from walking through the NPC without
inhibiting dialogue or changing the counter's existing collision.

The model's inspector-adjustable root proportions have been updated to
(2.32, 1.16, 2.38): a little shorter and visibly wider than before.
AnimationTree facial blending remains unchanged. The intro QA performs a
physics-space side raycast to verify a real collision, plus a skeleton
landmark check for the corrected height and shoulder proportions.
The large head prompt has also been reduced in size.

## Customer-facing corner counter (21 November 2026)

The small free-standing placeholder counter has been **removed**. The
replacement is a corner-mounted, L-shaped reception counter inside the
intro scene, using the existing `bar_side_material.tres` (Poly Haven dark
wood), `bar_top_material.tres` (Poly Haven worn tabletop) and
`roulette_wood_material.tres` (Poly Haven wood) including PBR normal
and roughness maps, plus restrained brass-colored trim.

In `gameplay/tutorial.tscn`, CroupierStation is placed at
`(-2.4, 0, -3.15)`, facing the room by a +90-degree Y rotation. The
main 3.75-meter counter runs toward the front wall at z = -4.72.
Its perpendicular return is joined to the left wall at x = -3.7.
Both have solid, joined collision shapes with physical overlap at the
wall endpoints so players cannot slip behind either end. The NPC is
station-local z = -0.52 and faces the customer side (+local Z, +world X).
The counter height is approximately 1.12 m relative to the 1.77 m NPC.

Conversation targeting is transformed into the station's local
coordinates, so the existing `E` dialogue still starts only from the
customer side. The imported `Rig|idle` animation, facial speech
AnimationTree filter and model scale remain unchanged. The existing
exit-door trigger and original player spawn stay in place.

The intro QA verifies both wall seams, both real physics collisions,
PBR material maps, NPC capsule, customer-only talking trigger, facial
animation mask, movement lock and original exit interaction.
