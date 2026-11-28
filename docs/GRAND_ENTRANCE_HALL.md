# Grand Entrance Hall — Phase 7B interior

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

## Reception branding and destination guidance

The original 1739 × 856 transparent branding PNG is displayed on the green
reception backdrop as an editable Sprite3D, about 5.22 × 2.57 m, with its
original aspect ratio, existing mipmaps and anisotropic texture filtering.
No new artwork or shared resource changes are needed.

The bilingual reception dialogue explains the new layout and the Main Casino
entrance. After the conversation closes, a small gold 3D downward arrow
appears in front of that door only, with a 0.12 m amplitude / 2.8 s hover
cycle. Guidance respects HUD, interaction and tutorial hints; reduced motion
holds the marker still. The marker is hidden during conversation and loading,
and resets on a new visit. The conversation remains optional and no profile
schema or progression change is introduced.

## Phase 7B — Furnishing and atmosphere

Four waiting ensembles occupy entrance-side lateral bays only. The two
larger conversation lounges use paired Poly Haven Sofa 02 and low Round
Wooden Table 01 models with chess/reading details; the two smaller waiting
nooks use a sofa and occasional table. Four claret rugs define these zones.
Furniture collisions are authored box/cylinder shapes derived from model
bounds; no seating interaction is added.

The 6.4 m counter retains its existing clearances and NPC placement.
Darker walnut, satin brass frames and a less reflective counter finish
strengthen its presence. Original desk bell and books with magnifier
rest on the counter; two Monstera plants and low wooden sideboards flank
the rear zone outside the future staircase area. Two marble busts on
removable pedestals greet visitors near the entrance. The original logo
is unchanged, with a second fine brass inset frame and ceiling-mounted wash.

The lower wall fields receive fine brass frames, four existing historic
paintings and four original Sketchfab wall sconces. Four scaled original
Poly Haven Chandelier 01 models hang from the centre of existing ceiling
fields, with visible canopy mounts. Their corresponding main lights
replace the former anonymous central fills; the rear fill is subdued.
Local lounge/sconce lights, logo and casino accents are non-shadow lights.
The original two shadow-casting lights remain the maximum budget. Ambient
illumination is reduced and screen-space ambient occlusion enabled subject
to existing graphics settings. Pale mineral surfaces have reduced noise
contrast, bump strength and normal influence; parquet and walnut are
darker and less shiny. No shared material is edited.

All additions are authored under Interior, with movable groups and
original PackedScene instances; no procedural furnishings, new assets,
runtime fitting scripts or new gameplay code. No external models are
required for this pass. A dedicated high-quality Art Deco armchair, floor
lamp and velvet rope set would be optional future assets. Reused model
credits already exist in ASSET_CREDITS.md (Poly Haven CC0 and the credited
Sketchfab sources).

Performance: prior hall had 525 authored nodes and 10 scene lights;
this version has 727 authored nodes and 18 scene lights, with
two dynamic shadow lights in both. Imported models share PackedScene
resources; runtime mesh counts are logged by QA. GPU frame time, startup
and visual quality require a real Forward+ comparison on the player's
machine rather than estimates based on node counts.

## Phase 7B — Selected detail assets

The seven user-supplied Poly Haven glTF models are added without texture
downscaling: alternate 2K historic paintings in two previously empty wall
panels, two 2K floor vases by the outer solid gallery bays (matching simple
cylindrical collision), 2K small vases on the reception, sideboard and waiting
table, three 1K decorative fire alarms, one 1K pocket watch lying face-up on
the reception counter and one 1K cigarette pack on a waiting table. All
instances are authored and individually movable. No additional light,
interaction, trigger or new gameplay mechanic is introduced. Existing
path/collision tests remain enabled, with original-source, surface-contact
and gallery clearance regressions for the added details.

## Phase 7B — Visual feedback pass

The entrance jambs and lintel now use aged bronze; bust pedestal columns use
the existing smoked walnut. The six brass counter frames close at butt joints.
All three fire alarms and the reception pocket watch are doubled in scale,
with support/wall contact preserved. The counter vase is removed; the four
remaining vase instances are distributed on the two rear cabinets. Each
cabinet is now approximately 1.02 m tall, as in the main casino, on a separate
3.78 × 0.24 × 0.93 m solid walnut plinth. Their original model and authored
collisions remain individually editable. The procedural mineral textures are
generated at 2048 × 2048 rather than 512 × 512 with finer grain and tighter
countertop tiling; they are not a photographic marble or stone PBR set.
Manual Forward+ visual and performance checks remain necessary.

## Phase 7B — Original 4K material replacement

The user-provided CC0 Plaster002 (walls), Stone Wall 03 (previous limestone
surfaces) and Travertine005 (reception countertop) replace the procedural
color and normal maps in those three hall-local materials. Original 4K
color, OpenGL normal and roughness images are pinned by SHA-256, with the
Poly Haven ARM green channel providing roughness. No displacement, glTF
geometry or duplicate copies are used. Existing bronze, brass and other
unrelated finishes are unchanged. Shared world-triplanar projection and
anisotropic filtering remain; material tints and normal strength are tuned
for the existing lighting. Run `python tools/ensure_assets.py` and
`python tools/ensure_hall_textures.py` before editor import if source maps
are missing. Actual Forward+ appearance and GPU memory/frame time need
manual verification.

## Phase 7B — Runner, light and entrance refinements

The main runner is a single UV-mapped plane with an 18.2 m continuous
length, touching the reception front and both brass inlays. It retains
the original woven material. The main runner and four lounge rugs are
tagged as authored carpet surfaces; the player selects the existing
carpet walk/run sounds from their actual local mesh extents. No carpet
collider or new audio resources are added. The main casino and Backrooms
surface rules are unchanged.

The two original shadowed omni lights are replaced by five downward
single-view spotlights across the nave and reception, with existing
non-shadow ambient/fill lighting retained. QA verifies downward-only
shadow cones and the light/projection budget; actual GPU performance
and shadow appearance require a Forward+ playtest. The entrance door,
jambs and lintel now meet precisely with the supporting wall, with
matching updated box collisions and the existing bronze finish.

## Crash diagnostics

The exported Windows game starts a local crash journal and an external monitor
using a content-keyed copy of the bundled updater outside the installation.
Loading and tutorial breadcrumbs are flushed immediately; a 15-second
heartbeat records the scene and available Godot memory monitors. Release
engine memory counters can be unavailable (zero). The monitor preserves the
exit code and matching Windows Application Error metadata when available.
Normal shutdown with code zero is not classified as a crash. Unexpected
termination produces a local crash_report.zip under user://crash_reports.
No automatic upload, memory dump or restart is made.

### Initial casino transition stability (crash #001)

The reported native access violation (0xC0000005, Godot 4.5.1 Forward+
Vulkan) occurred after the threaded PackedScene request returned OK and
the tutorial left the tree, but before casino activation completed.
This does not prove a specific engine function failed. As a targeted
mitigation only the tutorial-to-casino request uses serial dependency
workers; the request remains asynchronous. Direct menu loads and the
optimized room streaming are unchanged. Extra breadcrumbs cover the
tutorial tree exit (not guaranteed GPU resource destruction), the save
flag, first activation frames, casino root/controller initialization,
furniture and VoxelGI resource load/assignment. They are restricted to
initial activation and never perform synchronous journal I/O during
normal streaming. Monitor preparation now records hash, copy,
verification and launch durations independently; the existing integrity
checks remain in place.

Optional native dumps for a local diagnostic session: use Microsoft's
Sysinternals ProcDump (https://learn.microsoft.com/en-us/sysinternals/downloads/procdump),
run `procdump64.exe -e -w CasinoAnomaly.exe` from a writable diagnostic
folder before starting the game. This requests a default minidump on an
unhandled exception; engine exception handling can prevent capture.
It is an opt-in external diagnostic, not bundled or enabled automatically,
and does not change Windows registry settings. Dumps may contain private
process memory; review before sharing, and keep the regular crash ZIP.
Matching native debug symbols are needed for meaningful symbolized stacks.

## Phase 7B — Data-driven reception dialogue and objectives

The Croupier uses `gameplay/dialogue_catalog.gd` for conversation IDs, speaker,
context, ordered topic pages and optional objective IDs. Both English and
German localization live in the existing vocabulary. The reusable dialogue
view uses the common premium button theme, a lower-left speech column,
scrollable topic choices and explicit next/back navigation. It fits the
logical viewport and respects caption sizes and reduced motion. Additional
rooms may configure another validated conversation dictionary and connect
the objective_discovered signal to their own scene-local objective logic.
No dialogue is required to enter the casino, and no new save flag is added.

The scene-owned player objective HUD appears at the upper right only after
the player receives an informative page and closes the conversation. The
existing destination marker follows that same discovery. It fades in with
a one-shot gold accent reveal, respects HUD/tutorial/interaction settings
and reduced motion, hides during dialogue, pause and loading, and is freed
with the tutorial scene. The destination remains skippable. Classic-specific
streak instructions are explicitly labeled Classic; other mode rules are
unchanged.

### Returning guests

Before overwriting a run, the selected profile's existing valid run files
(across modes) and historical progress determine whether the guest is
returning. That result is saved as the optional `returning_guest` run
field, so continuing a first run retains its initial greeting. Existing
pre-feature profile saves default to returning; unbound editor/test runs
default to fresh. Renaming or switching profiles does not transfer guest
history, and deleting/recreating a profile removes it. Returning visitors
receive a separate two-page welcome plus an optional recognition topic.
Directions on the second greeting page discover the ordinary destination
objective; the recognition-only topic does not. No actual player names,
machine identity, or cross-profile tracking are used.

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
