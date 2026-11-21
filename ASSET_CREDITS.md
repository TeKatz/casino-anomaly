# Third-party 3D assets

All ten 3D models in `models/` are supplied by [Poly Haven](https://polyhaven.com/) under [CC0](https://polyhaven.com/license). Model identifiers, source pages, resolutions and pinned file hashes are recorded in `models/catalog.json` and `models/asset_index.json`. Imported models are not owned by Casino Anomaly. Existing Poly Haven wood and jacquard textures remain separately documented in `assets/*/source.json`.

Model source set: Chandelier_02, Chandelier_01, brass_candleholders, marble_bust_01, fancy_picture_frame_01, security_camera_01, wine_bottles_01, bar_chair_round_01, CoffeeCart_01, modern_wooden_cabinet.

The installer does not request assets from Poly Haven at runtime; model imports are downloaded and verified during development. Displayed source credit is provided in the menu.

## Sketchfab CC BY 4.0 — user-provided models

The five original casino prop models and the separately selected Business Man NPC use **Creative Commons Attribution 4.0**, not CC0.
The official license text is preserved in each extracted `models/sketchfab/*/license.txt`.
This game includes modified assets: PBR textures were downscaled for performance;
the *Poker set* was selectively reduced to a small cards/chips/dice prop GLB.
The original authors and source links must remain accessible whenever the
game or models are shared.

- **Roulette Table** — [Robilben](https://sketchfab.com/Robilben), [original](https://sketchfab.com/3d-models/roulette-table-18a27b0e326644a0b47887d07e0d0f99). CC BY 4.0.
- **Retro Slot Machine** — [ARTEL_3D](https://sketchfab.com/artel_3D), [original](https://sketchfab.com/3d-models/retro-slot-machine-46f0ae338d984364ac1249451067c1a3). CC BY 4.0.
- **Poker set** — [Matth_mat](https://sketchfab.com/Matth_mat), [original](https://sketchfab.com/3d-models/poker-set-841e271f392b4b3187b19fbdbb81ef62). CC BY 4.0. In-game use: selected 27,152-triangle display objects.
- **Blackjack Table** — [Ravi Jangid](https://sketchfab.com/ravijangid.rv), [original](https://sketchfab.com/3d-models/blackjack-table-baf7e3cbd14140ca81ea1a79d28fb635). CC BY 4.0.
- **Casino_2** — [crittaa](https://sketchfab.com/crittaa), [original](https://sketchfab.com/3d-models/casino-2-3f0e1cca9a3e46ba89f849e62df289ad). CC BY 4.0. This is a **complete room** and is kept in a separate preview rather than layered into the L-shaped hall.

- **Business Man – Low Polygon game character (intro Croupier)** — [manoeldarochadeoliveira](https://sketchfab.com/manoeldarochadeoliveira), [original](https://sketchfab.com/3d-models/business-man-low-polygon-game-character-b6f6740f883b4749abac47af0045a9dd), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Human NPC with rig, idle/talking animations and source PBR textures. The glTF is reoriented/scaled for the Godot welcome counter; attribution and its original license.txt are preserved in models/croupier/. The pinned Sketchfab ZIP is required before this character is included in a build.

License: https://creativecommons.org/licenses/by/4.0/

## New Poly Haven CC0 textures (architectural finish pass)

- **Wooden Panels** — [Poly Haven](https://polyhaven.com/a/wooden_panels), by Dimitrios Savva, CC0. Dark timber lower wall, 2K PBR maps.
- **Book Pattern** — [Poly Haven](https://polyhaven.com/a/book_pattern), by Rob Tuytel, CC0. Olive woven-fabric upper wall, 2K PBR maps.
- **Roof Planks** — [Poly Haven](https://polyhaven.com/a/roof_planks), by Rob Tuytel, CC0. Ceiling, 2K PBR maps.

The original Sketchfab Roulette Table model is used as a smaller roulette
**wheel** mounted on a new custom game table; the author/license remain
unchanged. The retro slot model is placed on a custom elevated stand.

## New user-selected materials and 3D models

All new materials and objects below are CC0, legally redistributable and retained under their original names. Source models are 1K original glTFs; source textures are 2K JPG PBR maps.

- [ambientCG Fabric037](https://ambientcg.com/view?id=Fabric037) — CC0; user supplied ZIP `Fabric037_2K-JPG.zip`; original color, OpenGL normal and roughness maps preserved verbatim, verified by SHA-256.
- [Poly Haven Wood Table 001](https://polyhaven.com/a/wood_table_001) — CC0; roulette cabinet timber.
- [Poly Haven Wood Table Worn](https://polyhaven.com/a/wood_table_worn) — CC0; bar counter top.
- [Poly Haven Dark Wood](https://polyhaven.com/a/dark_wood) — CC0; bar body and backboard.
- [Poly Haven Smoke Speckled Veneer](https://polyhaven.com/a/smoke_speckled_veneer) — CC0; pilasters and decorative pillars.
- [Poly Haven Round Wooden Table 01](https://polyhaven.com/a/round_wooden_table_01) — CC0; replaces five lounge coffee tables.
- [Poly Haven Sofa 02](https://polyhaven.com/a/sofa_02) — CC0; replaces five lounge sofas.
- [Poly Haven Chess Set](https://polyhaven.com/a/chess_set) — CC0; one chess display.
- [Poly Haven Concrete Cat Statue](https://polyhaven.com/a/concrete_cat_statue) — CC0; sculptural accent.
- [Poly Haven Horse Statue 01](https://polyhaven.com/a/horse_statue_01) — CC0; sculptural accent.

## Player-selected joinery materials (Poly Haven CC0)

The following original 2K JPEG diffuse, OpenGL normal and roughness maps are
imported by `tools/ensure_assets.py` from their exact Poly Haven source pages.
Source URLs and SHA-256 hashes are recorded under each `assets/*/source.json`.
The game requires no texture download during gameplay.

- [Brown Planks 05](https://polyhaven.com/a/brown_planks_05) — ceiling beams,
  wooden wall crowns and column base/capital transitions.
- [Herringbone Parquet](https://polyhaven.com/a/herringbone_parquet) — beveled
  timber perimeter of the L-shaped casino carpet.
- [Bi Stretch](https://polyhaven.com/a/bi_stretch) — warm gold-toned fabric
  inlays sitting directly on the parquet carpet border (a textile, not gold metal).

All three source materials are CC0-1.0 and remain attributed here for clarity.

## Game audio (crossfaded loop edits)

- **Menu music: "hmm.wav"** — Xythe, [Freesound #115831](https://freesound.org/people/Xythe/sounds/115831/), **CC0 1.0**. The original stereo recording was edited into a 92.754-second loop with a four-second head/tail overlap. Plays in the main menu only.
- **Continuous ambience: "casino_anomaly_room_tone_clean_loop(1).ogg"** — user-supplied sound recording with no verifiable original license metadata embedded in the file. Edited into a 13.219-second continuous loop with a 1.6-second crossfade. Its redistribution/attribution rights must be verified by the project owner before publishing the source archive publicly or commercial distribution.

The exact processed file hashes and the accompanying source notes are stored inside `audio_drop/casino_anomaly_seamless_audio.zip`. This package is extracted with `tools/import_audio.py` before Godot export; the source ZIP is not downloaded at runtime. Both streams play through the existing MUSIC/SFX volume buses and are started only from the persistent audio controller.
