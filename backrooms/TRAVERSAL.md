# Backrooms anomaly

The catalog entry `backrooms` participates in the ordinary random pool and G
developer picker (next round). It has no effect on the current casino's
architecture, lighting or signs. The first reference room stays anomaly-free.

Both doors take the player through their existing blind bend. At the reveal
threshold, the original player/controller is reparented into the authored maze
without a camera teleport, the departure path is physically sealed and the
environment switches to the maze's lighting. The original scene is unloaded.
The first passage has a physical flashlight and a nearby E interaction. Sprint
is disabled throughout the traversal; the flashlight has no battery mechanic.
A fluorescent hum replaces the regular casino room tone. No enemies or hazards.

Only crossing the far exit gives a successful verdict, adds one to the streak
and visited count, and records the discovery (unless developer-forced). The
actual door is still recorded for history, but either one is valid. Binary
decisions cannot consume this special round. At 12 the normal final hall is
loaded; otherwise the usual next-round selection continues. Leaving before
completion retains the saved pre-traversal casino round and streak. No checkpoint
inside the maze is needed. The return uses a sealed physical corridor and
preserves the player, then removes the flashlight and restores ordinary movement
and audio. The authored main and Backrooms scene files are not modified at runtime.

Test: `Godot --headless --path . --script res://tests/backrooms_traversal_qa.gd`
after editor import and the existing asset preparation. GPU lighting and
actual visual traversal should also be checked locally in Forward+.
