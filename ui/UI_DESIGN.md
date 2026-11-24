# Casino Anomaly UI foundations

- Obsidian and charcoal surfaces, champagne/gold highlights; green/red semantic buttons retained.
- Kenney UI Pack 2.0 (CC0) shapes adapted to the existing UI. The button palette is generated from simplified vector geometry at runtime, with cached symmetric nine-slice textures. No per-frame rasterization.
- Existing LuminousButton and MenuStyle remain the entry points. Existing gameplay, profile and option signal bindings are unchanged. Settings sliders, dropdown arrows and switches use selected Kenney-derived icons.
- Reduced menu motion bypasses button scaling and progress fill animation; existing overlay transitions remain. The UI sound uses the existing UI bus and synthesized click.
- Imported resources are limited to the selected SVGs; no wholesale asset pack import.
- Manual QA: main menu, profile slot actions, pause while in game, all six settings tabs, dropdown sizing at 36px, keyboard/controller navigation, reduced menu motion, UI volume, archive progress and profile switches. Check at 1280×720 and 1920×1080.
- Pending: external sound pack integration, dedicated achievement notifications, reactive card effects, runtime/visual verification.

Targeted regression script: `godot --headless --path . --script res://tests/ui_design_qa.gd` (run after editor import, preferably with an isolated user-data directory). Existing menu, profile and settings regressions should also be run.
