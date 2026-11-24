# Settings and graphics

The shared settings panel (main menu and pause menu) has five categories: Graphics,
Audio, Controls, Gameplay, General. All new strings have English/German text.
Complex graphics options have tooltips. The old config file and old TAA/VSync
keys are migrated; the old camera motion option seeds the independent panorama
motion option only on migration. There is no change to run/profile save data.

- Changes are applied by subsystem and saved after 350 ms of inactivity.
  Closing the settings or app flushes pending changes.
- Monitor, window mode and windowed resolution changes are temporary until
  confirmed. After 15 seconds they roll back, including the original screen
  and window bounds. Unconfirmed values are never written to disk.
- Resolution list contains common resolutions supported by the selected
  display dimensions and its actual native size, plus the current value.
  Exclusive fullscreen uses the desktop display size.
- Graphics presets change rendering options as a batch, and manual edits to
  preset-controlled values show Custom. Original preserves authored values.
- The scene's authored fog/SSAO/SSIL/glow availability is preserved; quality
  never enables a missing effect. Settings change actual renderer buffers,
  light shadows/distance, reflection capture visibility and particle counts.
  Baked lighting resources are not changed.
- Bilinear/trilinear/anisotropic sampling acts on StandardMaterial3D (and
  other BaseMaterial3D) samplers; custom shaders retain their own samplers.
  The renderer's anisotropy level is separately adjustable.
- FSR 1 and FSR 2 use actual viewport scaling; FSR 2 replaces other AA passes.
  Optional dynamic resolution is a conservative frame-rate feedback loop
  (not GPU timing), within 50% and the selected maximum gameplay scale.
  It waits multiple measurement windows, not a single streaming spike.
- Panorama render scale controls 3D only at native window output resolution;
  panorama motion, speed, darkness, still/abstract modes and FPS cap are
  independent of gameplay. The FPS cap is restored on leaving the menu.
- Performance overlay is opt-in. Reported frame time is the longest observed
  frame interval in the sampling window, not a GPU timer.

Texture asset quality tiers are not yet available. Reimporting or silently
downscaling the original texture assets is not part of this update.
The new graphics settings must also be evaluated in Forward+ on hardware;
headless tests validate configuration, runtime properties and scene lifecycle,
not image quality or GPU speed.

## Controls, audio and accessibility

Keyboard and mouse use two persisted physical bindings per gameplay action. Conflicts are rejected; Escape remains an emergency pause/back key and developer shortcuts are reserved. The gamepad uses left/right sticks, L3 sprint, A interaction and Start pause, with adjustable sensitivity/deadzone and optional interaction vibration. Input hints follow the active device. Individual camera motion sliders do not change player speed.

Audio controls route ambience, footsteps, cabinets, horror and pressure through independent buses with the master/SFX volume hierarchy. Night mode uses a compressor; output device, balance, mono and focus mute are independent. Sound captions are non-directional and never announce a hidden anomaly.

Accessibility options include motion reductions, soft Backrooms entry lighting, decorative light steadiness, UI scale and text size, high-contrast panels, UI icon palettes, extra choice symbols, caption size/background and reduced horror audio. Actual anomaly colors, scoring, route conditions and authored geometry are unchanged. Tutorial skipping preserves the guaranteed normal first room. Controller, display and audio hardware need manual testing. Dialogue is currently text-only; no voice volume is exposed.
