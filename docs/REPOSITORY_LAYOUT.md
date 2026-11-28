# Repository structure

Godot 4.5.1 project. Open the root `project.godot` in Godot. This
layout migration changes resource paths only, not the authored geometry,
runtime algorithms, save data or Windows distribution layout.

| Location | Responsibility |
|---|---|
| `gameplay/casino/` | Main casino scene, hall, atmosphere and furniture placement |
| `gameplay/` | Player, tutorial, dialogue, progression, anomalies, streaming and settings |
| `ui/` | Main menu scene and script, HUD, dialogs, UI components |
| `assets/materials/` | Shared authored PBR materials formerly at the root |
| `assets/`, `models/`, `audio/`, `branding/` | Original and game-ready resources |
| `source_assets/audio_drop/` | Source audio archives |
| `source_assets/sketchfab_drop/` | Source furniture/NPC archives and catalog |
| `source_assets/tutorial_assets_drop/` | Source tutorial prop archives and catalog |
| `lighting/`, `backrooms/` | Existing baked lighting and Backrooms assets |
| `addons/`, `editor/`, `tools/` | Editor plugins, import and maintenance tools |
| `tests/` | Regression tests and QA fixtures |
| `src/` | Windows updater and crash monitor |
| `docs/` | Technical documentation and historical notes |

Main Casino: `gameplay/casino/main.tscn`; entrance hall:
`gameplay/grand_entrance_hall.tscn`; main menu: `ui/menu.tscn`.

The root `ASSET_CREDITS.md` is deliberately retained for the release
packager. Project, export and version configuration stay at the root.
Asset hashes, import sidecars and existing script UIDs remain unchanged
apart from necessary resource-path edits. No player data under
`user://` is moved.

## Existing local Godot checkout

Close Godot before pulling the layout update. Preserve any local work
before pulling. Reopen `project.godot` and let Godot refresh its resource
index; reopen the main casino scene from its new path. If local source
archives were never tracked, move them from the old drop folders into
the corresponding `source_assets/` folder yourself. Do not delete the
project or player saves to resolve a stale editor cache.

The previous Silent Audience installation notes are retained in
`docs/archive/SILENT_AUDIENCE_INSTALLATION.md` for historical reference;
they do not describe the current game's installation.
