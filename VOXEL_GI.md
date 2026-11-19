# VoxelGI – Casino Anomaly (Godot 4.5.1)

The casino has two **room-local** `VoxelGI` volumes, `MainWingGI` and
`WestWingGI`, at 128 subdivisions each. Their transforms follow each
streamed room, including 180° rotations, and are disabled in standby halls.

**The nodes alone provide no GI.** They require nonempty baked binary
resources in `lighting/main_wing.res` and `lighting/west_wing.res`.
Without both resources, the game safely retains its existing Forward+
lighting with zero VoxelGI shader/probe cost. The graphics setting toggles
VoxelGI once valid baked resources are included.

## Bake once with a real rendering device

1. Check out the repository on `dev` with all texture/model dependencies
   available (the normal asset import scripts are in `tools/`).
2. Install **Godot 4.5.1** and run, in the project directory:
   `Godot_v4.5.1-stable_win64_console.exe --path . --script res://tools/bake_voxel_gi.gd`
   **Do not** use `--headless`. Godot needs Vulkan/D3D12 for GPU-based
   emission voxelization and baking. Both resources are generated once.
3. Verify `lighting/main_wing.res` and `lighting/west_wing.res` exist
   and have nonzero voxel data. Visually inspect the casino in Godot.
4. Commit those **binary** files to GitHub to include GI in future
   Windows builds. Re-bake after changing static furniture, geometry,
   or emissive lighting.

The offline script adds temporary *thickened* warm/cyan emissive proxies:
the actual 3–4 cm light strip meshes are too thin to reliably show up in
128-subdivision GI voxels. These bake-only meshes are not shipped or
rendered during gameplay. The script never saves over the authored
`main.tscn`.

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

**Current status:** infrastructure is present; visible GI requires the
two actual baked .res files. Do not describe the unbaked build as active
VoxelGI.
