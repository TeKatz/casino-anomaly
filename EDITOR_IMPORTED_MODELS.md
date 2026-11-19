# Imported casino models in the Godot editor

The `SketchfabFurniture` node in `main.tscn` now builds a **transient
editor-only preview** of the same four replacement types the game loads:
three roulette wheel + mahogany table assemblies, the blackjack table
with poker props, and the retro slot machine with its pedestal.

The ZIP originals live under `sketchfab_drop/`. Unlike CI, a local Git
checkout initially does NOT contain `models/sketchfab/` because the
extracted models are git-ignored. The editor plugin automatically extracts
the five verified CC BY ZIPs and scans/imports their glTF assets on project
open; no Python installation is required. The archive checksum is validated
against `sketchfab_drop/catalog.json`. If automatic installation fails,
run `python tools/unpack_sketchfab_assets.py --require-all` from the
project root and then reopen Godot.

Open or reopen `main.tscn` in Godot 4.5.1. The replacement meshes should
appear in the 3D editor view, while their original procedural placeholders
are temporarily hidden. The remaining Poly Haven models are already
previewed by `editor/model_placement_preview.gd`.

To toggle or rebuild these models, select the `SketchfabFurniture` node
and switch **Show Imported Models In Editor** off and on in Inspector.
If some meshes remain missing, allow Godot's asset import to finish
and toggle the preview again.

The preview uses the **same placement code** as runtime but builds no
extra physics bodies, emits no runtime signals, and is parented under an
internal non-owned node. It is deliberately not written into `main.tscn`
and does not replace the game's live instances or streaming logic.

For lighting changes that need to persist, edit the actual authored
`WorldEnvironment`, light nodes, and `main.tscn` resources. The
procedural/editor preview models are reference geometry; gameplay
still creates its real furniture and collisions when a run begins.

The built-in `Casino Model Preview` editor plugin (enabled by default)
temporarily restores the original placeholder visibility just before
the editor saves the scene, then regenerates the imported preview afterward.
This prevents temporary hidden placeholder states from being serialized
into `main.tscn`. If you manually disable the plugin in Project Settings,
toggle the `SketchfabFurniture` preview **off before saving** and back on
afterward.

Tested with `tests/sketchfab_editor_preview_qa.gd`.
