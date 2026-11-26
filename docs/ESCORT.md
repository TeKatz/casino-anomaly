# The Escort

A single Security Guard waits at the west aisle, activates on camera visibility,
approaches, observes at a 2.25–2.95 m band, and backs off when approached.
It follows only within its room. Physical steering uses capsule collision/floor
probes and an isolated NavigationAgent/NavigationRegion, with a local fallback
while the navigation mesh is baking. It cannot guarantee the requested gap
when cornered or chased at sprint speed; it never teleports.

## Source asset
From the repository root, run:
```sh
python tools/import_escort_animations.py
```
or use your original archive offline:
```sh
python tools/import_escort_animations.py --archive "/path/to/Universal Animation Library[Standard].zip"
```
Open/reimport in Godot 4.5.1. CI installs the same checksum-pinned GLB before
each engine import/export. No runtime downloads. The original five models
are not altered. The mannequin is hidden; native RetargetModifier3D transfers
authored rotations onto the Security Guard. The model keeps its bone lengths
and scale. Reverse formal walk is a temporary substitute for a dedicated
backpedal clip; this library has none. The AnimationTree blends forward,
idle, and reverse with speed matching. No Silent Audience behavior is restored.

## Review
Select The Escort in the developer anomaly menu after the reference room.
Check scale, foot placement, forward/backward motion, and corners. Headless
QA checks real imported clips, bone motion, spawn clearance, state transitions
and cleanup; it does not certify rendered animation quality.
