# Grand Entrance Hall — Phase 7A blockout

This is the live authored tutorial scene. The stable entry point
`gameplay/tutorial.tscn` instances this hall, so existing saved runs and
all menu/pause entry routes keep their original path. Open `gameplay/grand_entrance_hall.tscn` in Godot 4.5 (Forward+)
and press **F6 / Run Current Scene**. Use the existing movement, sprint,
mouse look and pause controls. F5 starts the normal main menu and a new Classic run enters this hall.
Alternatively: `godot --path . res://gameplay/grand_entrance_hall.tscn`.
Only the east rear door leads to the casino, using the existing E/controller
interaction and threaded SceneLoader. The three other doors are reserved,
solid and non-interactive. To test the complete progression, start a new
Classic run from F5; F6 is useful for editor inspection.

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
  customer marker at (0,0,-5.10). The live CroupierStation preserves the original authored model overrides,
  native idle/facial animation and optional bilingual dialogue.
- Two open arcades per wing, divided by a central structural pier.
  Four 2.4 m wide, 3.1 m high double-door blockouts on the outer gallery
  walls at x ±12.15 and z -4 / +2. East rear door is the active main casino connection. The other three
  are marked UNDER CONSTRUCTION. All have solid door leaves.
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
runner, upper wall insets and reception panel trim are authored nodes. The NPC is a saved editable instance at the central reception. The previous
room is retained only as an archived asset/geometry reference in
`gameplay/legacy_tutorial.tscn`; no live gameplay route loads it.

## QA

Run `godot --headless --path . --script tests/grand_entrance_hall_qa.gd`
after normal project import. The existing CI groups on Linux and Windows
include the new test: authored collision matching, capsule clearance
on main/side/staff routes, floor continuity, closed door collision,
central NPC sightline, player gravity and 49-entry catalog/main scene
contract. All old tutorial and gameplay tests remain enabled.
Material coverage and the reported coplanar joints are checked as well.
Visual NPC placement, materials, lighting and real Forward+ performance
still require manual review. The live tutorial reuses existing dialogue,
accessibility, save schema, and loading flow. No changes to the main casino
or anomaly catalog. The legacy dressing regression continues to check the
archived assets; all live NPC and transition tests target the new hall.
