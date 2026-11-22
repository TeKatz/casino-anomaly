# VoxelGI – Casino Anomaly (Godot 4.5.1)

The casino has two **room-local** `VoxelGI` volumes, `MainWingGI` and
`WestWingGI`, at 128 subdivisions each. Their transforms follow each
streamed room, including 180° rotations, and are disabled in standby halls.

## See baked VoxelGI in the Godot 3D editor

Open `main.tscn` with Godot 4.5.1 and the Forward+ renderer.
The `@tool` scene script creates a **temporary, ownerless** `VoxelGIRig`
in the editor. Both probes load the same already baked binary data used
in the running game, and are enabled in the editor independently of the
player's saved graphics setting.

You should see the indirect, warm bounced lighting even while using
`Player/Camera3D` camera preview. Scene-specific editor lighting and
environment must also remain enabled. There is **no editor rebake** and
the transient probes are never saved into `main.tscn`.

Godot editor rendering is still not an exact game screenshot: graphics
settings and runtime effects such as image contrast, animated slot lights,
and any dynamically generated objects may differ. Reopen `main.tscn`
after pulling code changes if its previous preview is still open.

Regression: `tests/voxel_gi_editor_preview_qa.gd` executed under
`--headless --editor` verifies both pre-baked probe resources are loaded
and their editor instances are visible and ownerless.

**The nodes alone provide no GI.** They require nonempty baked binary
resources in `lighting/main_wing.res` and `lighting/west_wing.res`.
Without both resources, the game safely retains its existing Forward+
lighting with zero VoxelGI shader/probe cost. The graphics setting toggles
VoxelGI once valid baked resources are included.

## Re-bake directly from the Godot editor (recommended)

1. Open **main.tscn** in Godot **4.5.1**, using the Forward+ renderer.
   Move, rotate or resize the neon strips/sign frames and adjust their
   emissive material colors/strengths as needed.
2. Choose **Project → Tools → Casino: VoxelGI neu backen...** (the existing
   Casino Model Preview editor plugin must be enabled).
3. Confirm **Speichern und backen**. Godot saves all open scenes, then launches
   a **separate GPU-backed Godot process** to bake both room-local probes.
   Do not edit main.tscn again until this process finishes.
4. Look for `Casino Anomaly VoxelGI OFFLINE BAKE PASS` in that process's
   output. Reopen main.tscn after the bake to reload the updated editor GI
   preview. Visually inspect both casino wings.
5. Commit `lighting/main_wing.res` and `lighting/west_wing.res` alongside
   any intended scene edits. Do **not** commit generated runtime caches.

The baking script now derives thickened **bake-only proxies from each saved
emissive cove or entry/bar sign frame segment** in CasinoAtmosphere.
Position, rotation, scale, length, emission color and emission strength follow
the actual authored MeshInstance3D/BoxMesh. This replaces six fixed-coordinate
bake placeholders. Each strip's minimum thickness is 0.28 m for reliable
128-division voxelization. Original thin strips are excluded from the bake
to avoid double contribution; neither the proxies nor any changes to
the original strips are saved to main.tscn.

### Console fallback

If the plugin is disabled, close the Godot editor, then run from the project
directory:

`Godot_v4.5.1-stable_win64_console.exe --path . --script res://tools/bake_voxel_gi.gd`

**Never add `--headless`:** VoxelGI requires a GPU-backed rendering device.
The script still writes the two external .res resources and prints a PASS
message after validating nonempty VoxelGI data. The GitHub CI tests the proxy
mapping and resource contracts but cannot produce a GPU-backed bake.

**Important:** Only emissive geometry that is saved to disk is baked. Unstaged
scene changes are included if they have been saved; changing a neon in the
editor after the bake begins does not affect that bake. 

## Performance and streaming

- Two volumes per active hall, with one complete baked data set reused
  by every streamed room instance.
- Standby rooms load probes disabled and activate them only *after* the
  previous room has been unloaded. No blocking bake at run transitions.
- The player can turn VoxelGI on/off under **Settings → Graphics**.
- VoxelGI supports Forward+ on discrete GPUs; integrated GPUs may need
  the off setting. Compare FPS and VRAM before making it mandatory.
- The direct shadows under tables still need shadow maps. VoxelGI gives
  bounced light and color bleeding, not replacement direct shadows.
- Streaming modifies doors/corridors at runtime. These are not included
  in the static GI bake. Watch for light leaks at the exit sleeves;
  use geometry seals or separate bake occluders if necessary.
- The CI build uses `--headless` and **cannot generate** the binary GI
  resource. It verifies the rig and exports any committed .res files.

**Current status:** both baked binary assets are present in
`lighting/` on `dev`. Real-time VoxelGI is available during gameplay and
now also previewed in the Godot editor. Regenerate the bake only after
changing geometry or lighting that contributes to the static bake.
