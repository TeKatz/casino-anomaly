# Backrooms anomaly

The catalog entry `backrooms` participates in the ordinary random pool and G
developer picker (next round). It has no effect on the current casino's
architecture, lighting or signs. The first reference room stays anomaly-free.

Both doors take the player through their existing blind bend. At the reveal
threshold, the original scene root, player, camera and menus stay continuously in the
SceneTree. The authored maze is attached at its existing world transform,
the departure path is sealed and the retired casino geometry is unloaded.
The empty scene shell is disposed on return to the next casino.
The first passage has a physical flashlight and a nearby E interaction. Sprint
is disabled throughout the traversal, with a 2.1 m/s walking cap from reveal.
The flashlight uses a 0.95 energy, 9 m spot and no battery mechanic. The
pickup hint is a screen-space label, independent of view direction but blocked
by real intervening walls. The original OneWayGate alone seals the entry.
The oak floor and carpet meet at a fitted edge, with matching collider.
Ambient and ceiling illumination are reduced; rebake Backrooms VoxelGI after
this lighting pass (older data is capped at runtime).
A fluorescent hum replaces the regular casino room tone. No enemies or hazards.

Only crossing the far exit gives a successful verdict, adds one to the streak
and visited count, and records the discovery (unless developer-forced). The
actual door is still recorded for history, but either one is valid. Binary
decisions cannot consume this special round. At 12 the normal final hall is
loaded; otherwise the usual next-round selection continues. Leaving before
completion retains the saved pre-traversal casino round and streak. No checkpoint
inside the maze is needed. The return uses a sealed L-shaped corridor with a fixed EXIT arrow pointing
right at its end wall. The next casino is prewarmed
behind its blind bend. Ambient light, fog and post-processing blend by walking
distance on a temporary Environment copy, and the flashlight fades out. The
exact destination Environment is active before the bend, with no environment
reassignment at visible handoff. The handoff takes place 0.75 m beyond the
actual casino entrance plane, with no narrow centerline restriction once in
the hall. The player is preserved and ordinary 4.0 m/s walking, 6.3 m/s
sprint and audio are restored on return. The authored main and Backrooms scene files are not modified at runtime.

Test: `Godot --headless --path . --script res://tests/backrooms_traversal_qa.gd`
after editor import and the existing asset preparation. GPU lighting and
actual visual traversal should also be checked locally in Forward+.

## Streaming cost

Maze preparation and return casino assembly use three separate frame phases.
Once a physical exit gate seals the previous area, its visual geometry and
light volumes are disabled, leaving only the traversable connector and the
active environment. Structural opaque boxes carry inset occluders; no door
opening, collision or authored material is changed. The normal casino
handoff also uses the entrance plane rather than a narrow centerline.
Actual frame-time and GPU improvement must be measured in Forward+.

In a running game, Ctrl+F9 toggles a console performance sample once per
second (phase, FPS, maximum observed frame interval, process/physics times,
render draw calls/objects/primitives, staging phases and local position).
It is disabled by default. These are engine counters, not GPU timings.
Compare looking into the casino and back into the sealed return corridor.
