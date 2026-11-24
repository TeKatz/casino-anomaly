# Main menu casino panorama and startup

Godot's ordinary boot splash is unchanged. The menu opens with an opaque branded
intro (existing portal logo, CASINO ANOMALY and A game by TeKatz). A first-launch
cover fades in and holds for at least 1.6 seconds, but fades out only after the
casino viewport has actually rendered six warmup frames. On menu return the
same gate is a short dark cover without repeating the creator splash. Missing
assets or a 30-second loading timeout permit the fallback menu to be used.

The background renders current main.tscn visual geometry in an isolated
World3D/SubViewport. A TextureRect displays its native window-pixel texture,
independent of the 1280x720 logical UI canvas. TAA follows the existing setting;
the texture uses linear sampling and the viewport uses 8x anisotropy. The
camera sweeps over the main aisle on a 42-second cycle. Gameplay, live
reflections, GI rig, particles and room audio remain disabled. The panorama is
suspended during game loading. No baked resources or gameplay geometry change.

The foreground is sized to its visible controls, right-aligned on wide
screens and centered on compact screens. The brand is raised and reduced.
The intro is editable in ui/menu_startup_intro.tscn. Actual GPU appearance,
frame pacing and startup duration should be checked in Forward+.

## Player-configurable menu quality

Graphics now includes a separate panorama mode (live / still / abstract), native-window scale, frame cap, motion toggle, speed and dimming. The frame cap applies to the menu only; gameplay restores its own cap. The previous camera-motion preference is migrated once and then independent.
