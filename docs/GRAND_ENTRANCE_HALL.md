# Grand Entrance Hall — Phase 7A blockout

This is an isolated, authored scene, not a replacement for the existing
tutorial. Open `gameplay/grand_entrance_hall.tscn` in Godot 4.5 (Forward+)
and press **F6 / Run Current Scene**. Use the existing movement, sprint,
mouse look and pause controls. F5 still starts the normal main menu.
Alternatively: `godot --path . res://gameplay/grand_entrance_hall.tscn`.
The four doors are deliberately solid and have no transition or interaction.
Do not start a new run from the preview's ordinary pause menu if you want
to stay in the blockout.

## Plan (meters, local scene coordinates)

- Clear main nave: 16 wide (x -8 to +8), 28 deep (z -14 to +14),
  ceiling 8.6 high. Side galleries add 4 m each (overall 24 m at
  the cross-wing); z -7 to +5, height 4.6. Exterior includes wall thickness.
- Spawn at (0, 1.02, 12), looking along -Z. Camera offset 0.55 m,
  same capsule and controller as the original tutorial (settled eye 1.485 m).
- Main colonnade at x ±5.25; four pairs of piers create a broad central
  nave and lateral furnishing zones. The two thin floor inlays frame
  the 4.88 m wide burgundy runner.
- Reception centered at z -6.45; 6.4 m front, 1.09 m countertop,
  returns and open staff access behind. NPC marker at (0,0,-7.60);
  customer marker at (0,0,-5.10). The real tutorial NPC and its behavior
  remain unchanged in the original scene.
- Two open arcades per wing, divided by a central structural pier.
  Four 2.4 m wide, 3.1 m high double-door blockouts on the outer gallery
  walls at x ±12.15 and z -4 / +2. East rear door is the future main
  casino connection. Other three are reserved; all four are closed.
  Each access has a connection and approach marker for future work.
- Rear space behind reception (roughly x -4.5 to +4.5, z -8.8 to -13.6)
  reserved for a future double staircase. Three design markers indicate
  potential stair starts and upper landing. No stairs, floor slab,
  upstairs doors or invisible barriers have been added.

## Editor structure

Architecture (Floors, CentralAxis, MainWalls, Arrival, Colonnade,
Ceiling, ReceptionBackdrop), SideGalleries (Shell and AccessBays),
Reception, FutureExpansion, Lighting, DesignMarkers, Player.
All blockout geometry is serialized in the TSCN. Solid objects are
StaticBody3D nodes with matching BoxMesh and BoxShape3D children.
Repeated dimension resources are shared but are never modified at runtime;
make a resource unique before resizing an individual mesh/shape, or scale
the whole owning body uniformly. No procedural architecture runs in game.
The material pass uses hall-specific PBR materials, existing herringbone,
woven fabric, walnut veneer and jacquard textures, and seamless procedural
mineral color/normal maps for stone, plaster and metal. Triplanar mapping
prevents stretching on large architectural surfaces. No shared casino
material is modified and no external assets are downloaded. The gallery
ceiling and end walls meet adjoining geometry without overlapping visible
planes; the countertop returns meet the front slab edge-to-edge. The
runner, upper wall insets and reception panel trim are authored nodes. NPC
placeholder is an editor marker, not a second tutorial implementation.

## QA

Run `godot --headless --path . --script tests/grand_entrance_hall_qa.gd`
after normal project import. The existing CI groups on Linux and Windows
include the new test: authored collision matching, capsule clearance
on main/side/staff routes, floor continuity, closed door collision,
central NPC sightline, player gravity and 49-entry catalog/main scene
contract. All old tutorial and gameplay tests remain enabled.
Material coverage and the reported coplanar joints are checked as well.
Visual surface quality, lighting and real Forward+ performance still need
manual F6 review before furnishing and tutorial integration. This scene does not add a gameplay route,
change a profile, implement dialogue, or affect main branch.
