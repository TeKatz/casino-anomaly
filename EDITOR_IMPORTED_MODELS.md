# Imported casino models in Godot 4.5.1

The five verified Sketchfab packages are stored as ZIPs in
`sketchfab_drop/`. The enabled editor plugin extracts them to the ignored
`models/sketchfab/` directory and imports their glTF scenes automatically
when the project opens. If import is still in progress, wait for the editor
filesystem scan to complete before using the tools menu.

## Make imported furniture selectable and editable (once)

1. Open `main.tscn` from the `dev` branch.
2. In Godot choose **Project > Tools > Casino: Importierte Modelle bearbeitbar machen**.
3. Save the scene with **Ctrl+S**. The model objects are now normal, saved,
   editable scene instances, not merely non-selectable editor previews.
4. In the Scene tree, expand **SketchfabFurniture > EditableImportedModels**
   for the retro slot machine, roulette assemblies, blackjack table, poker
   accessories, and the procedural supporting furniture. Expand
   **ModelInteriors** and its placement markers to reach their new
   **EditableImportedModel** child for Poly Haven furniture.
5. Select the model in the Scene tree (or directly in the 3D view when Godot
   picks the mesh), then translate, rotate, or scale it with the usual tools.
   Save `main.tscn` again. Changes are used in the game, too.

The editor action is idempotent and can be run again. It only converts each
model once and does not create duplicates. Imported mesh geometry remains an
instance of the original glTF source. To modify the meshes/material nodes
*inside* an imported scene, right-click the imported scene node and select
**Editable Children**; for normal placement edits this is not needed.

The authored 3D model and its transform are used at runtime instead of
reconstructing another copy. Poly Haven furniture collision shapes are still
created at runtime based on the edited model bounds. Sketchfab colliders and
supports are saved together with the editable furniture group.

## Before converting

`SketchfabFurniture > Show Imported Models In Editor` toggles an
**ownerless transient preview** that is for inspection only: the meshes are
rendered in the 3D viewport but cannot be selected and edited as scene nodes.
The Poly Haven placement markers work similarly, with internal glTF previews
that track their saved anchors.

The built-in editor plugin temporarily restores the original procedural
Sketchfab placeholders just before saving an unconverted scene so the hidden
state does not accidentally persist. It then rebuilds the previews after the
save. Once you convert, the original placeholders are deliberately hidden in
`main.tscn` and the authored imported furniture is authoritative.

If local assets do not show up, let Godot finish importing, toggle the
Sketchfab preview off/on, or reopen the project. As a fallback run
`python tools/unpack_sketchfab_assets.py --require-all` from the project
folder. The donor asset checksums are verified against
`sketchfab_drop/catalog.json`.

The converter is implemented in
`addons/casino_model_preview/plugin.gd`,
`sketchfab_furniture.gd`, and
`editor/model_placement_preview.gd`.
