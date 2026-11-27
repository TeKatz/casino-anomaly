# Third-party 3D assets

All ten 3D models in `models/` are supplied by [Poly Haven](https://polyhaven.com/) under [CC0](https://polyhaven.com/license). Model identifiers, source pages, resolutions and pinned file hashes are recorded in `models/catalog.json` and `models/asset_index.json`. Imported models are not owned by Casino Anomaly. Existing Poly Haven wood and jacquard textures remain separately documented in `assets/*/source.json`.

Model source set: Chandelier_02, Chandelier_01, brass_candleholders, marble_bust_01, fancy_picture_frame_01, security_camera_01, wine_bottles_01, bar_chair_round_01, CoffeeCart_01, modern_wooden_cabinet.

The installer does not request assets from Poly Haven at runtime; model imports are downloaded and verified during development. The in-game Credits panel links back to these sources.

## Monstera Deliciosa Potted Mid-Century plant — Giora (CC BY 4.0)

Source: https://sketchfab.com/3d-models/monstera-deliciosa-potted-mid-century-plant-1ab9bf841df04c07b1819be596327629
Author: https://sketchfab.com/ChubbyPanda
License: https://creativecommons.org/licenses/by/4.0/

The uploaded source package includes the explicit license text. Optimized
textures retain the original UVs, foliage alpha, pot and stand and their
material associations. This model must be distributed with attribution.

## Sketchfab CC BY 4.0 — user-provided models

- **Playing Cards (52 individual cards)** — [jdastine](https://sketchfab.com/jdastine), [source](https://sketchfab.com/3d-models/playing-cards-2dd7c45bf68a4ce3bf63c995b1bf12bf). The uploaded set was split into 52 separately editable 3D glTF assets, with a shared optimized source-texture atlas, and selected examples placed on Blackjack and lounge tables. A [published third-party credits sheet](https://margaridabelo.myblog.arts.ac.uk/files/2023/05/credits.pdf) identifies the model as CC BY 4.0; its supplied `license.txt` does **not** expressly state a Creative Commons license and the glTF identifies jdastine as copyright holder. Preserve credit and verify permission with the author if distribution terms are uncertain. Source/license details and original material mapping are in `models/playing_cards/`.


The four original casino prop models and the separately selected Business Man NPC use **Creative Commons Attribution 4.0**, not CC0.
The official license text is preserved in each extracted `models/sketchfab/*/license.txt`.
This game includes modified assets: PBR textures were downscaled for performance;
the *Poker set* was selectively reduced to a small cards/chips/dice prop GLB.
The original authors and source links must remain accessible whenever the
game or models are shared.

- **Roulette Table** — [Robilben](https://sketchfab.com/Robilben), [original](https://sketchfab.com/3d-models/roulette-table-18a27b0e326644a0b47887d07e0d0f99). CC BY 4.0.
- **Retro Slot Machine** — [ARTEL_3D](https://sketchfab.com/artel_3D), [original](https://sketchfab.com/3d-models/retro-slot-machine-46f0ae338d984364ac1249451067c1a3). CC BY 4.0.
- **Poker set** — [Matth_mat](https://sketchfab.com/Matth_mat), [original](https://sketchfab.com/3d-models/poker-set-841e271f392b4b3187b19fbdbb81ef62). CC BY 4.0. In-game use: selected 27,152-triangle display objects.
- **Blackjack Table** — [Ravi Jangid](https://sketchfab.com/ravijangid.rv), [original](https://sketchfab.com/3d-models/blackjack-table-baf7e3cbd14140ca81ea1a79d28fb635). CC BY 4.0.

- **Business Man – Low Polygon game character (intro Croupier)** — [manoeldarochadeoliveira](https://sketchfab.com/manoeldarochadeoliveira), [original](https://sketchfab.com/3d-models/business-man-low-polygon-game-character-b6f6740f883b4749abac47af0045a9dd), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Human NPC with rig, idle/talking animations and source PBR textures. The glTF is reoriented/scaled for the Godot welcome counter; attribution and its original license.txt are preserved in models/croupier/. The pinned Sketchfab ZIP is required before this character is included in a build.

License: https://creativecommons.org/licenses/by/4.0/


## Retained character assets — five user-provided rigged people (adapted)

Original Sketchfab downloads and their actual license.txt are included in the optimized guest asset pack at models/silent_audience/<model>/license.txt. Character bones and skinned meshes are preserved. Source textures were resized and recompressed, and unused female morph targets/source animation were removed. The gun/smoking meshes of the second Guard are hidden in the supplied game-ready glTF. The independent game code is not claimed to be part of the creators' artwork.

- **Security Guard – Rigged 3D Model** — [Q.SARDOR](https://sketchfab.com/qsardor57913), [original](https://sketchfab.com/3d-models/security-guard-rigged-3d-model-1e3307732bbf4453b30f021bfec5bcaf), **CC BY 4.0**.
- **old man in coat – human riged model** — [mohsenmousavi2313](https://sketchfab.com/mohsenmousavi2313), [original](https://sketchfab.com/3d-models/old-man-in-coat-human-riged-model-e8052f5928ef42f1ae5b5af02eb1a36b), **CC BY 4.0**.
- **Indian Man in suit** — [Pixel_Monster](https://sketchfab.com/ar.jethin), [original](https://sketchfab.com/3d-models/indian-man-in-suit-985dd9756d89464b9380414b5b12d8aa), **CC BY 4.0**.
- **guard** — [DJMaesen](https://sketchfab.com/bumstrum), [original](https://sketchfab.com/3d-models/guard-9f146fae6af1482ab6bff56ed5677c28), **CC BY 4.0**.
- **Realistic Female** — [Biviyt](https://sketchfab.com/Biviyt), [original](https://sketchfab.com/3d-models/realistic-female-b0cc2a6c26114da184252e433cf75d23), **CC BY-SA 4.0**. This adapted character asset remains under CC BY-SA 4.0; redistribution must preserve this license and original attribution.

License references: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

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
- **Continuous ambience: "casino_anomaly_room_tone_clean_loop(1).ogg"** — based on **"Room Tone In An Apartment Living Room 2"** by **leonelmail**, [Freesound #329533](https://freesound.org/people/leonelmail/sounds/329533/), **CC0 1.0** ([Freesound license listing](https://freesound.org/people/leonelmail/sounds/329533/)). User-supplied recording edited into a 13.219-second seamless loop with a 1.6-second crossfade; the original Freesound recording is 17.307 seconds long.

The exact processed file hashes and the accompanying source notes are stored inside `audio_drop/casino_anomaly_seamless_audio.zip`. This package is extracted with `tools/import_audio.py` before Godot export; the source ZIP is not downloaded at runtime. Both streams play through the existing MUSIC/SFX volume buses and are started only from the persistent audio controller.


## Tutorial decorations — Sketchfab CC BY-SA 4.0 and CC BY 4.0

All four original Sketchfab source ZIPs have been committed to the repository,
including the model meshes, PBR textures and original license files. The
three CC BY models were uploaded on `main` and copied unchanged to
`dev/tutorial_assets_drop`; the CC BY-SA books were uploaded directly to
`dev`. They are imported at build time and used in the tutorial room.
Original geometry is uniformly scaled, oriented and mounted on existing
surfaces; the originals and license statements remain available.

- **Wall Light** — Lucas Garnier, [Sketchfab original](https://sketchfab.com/3d-models/wall-light-c723fa0a1ac3478790192acdb39161b0), CC BY 4.0.
- **Vintage Gramophone** — Maxim Mavrichev, [Sketchfab original](https://sketchfab.com/3d-models/vintage-gramophone-a7508a4233a344008029d21a2f0024bd), CC BY 4.0.
- **Books with magnifier** — **shuvalov.di**, [Sketchfab original](https://sketchfab.com/3d-models/books-with-magnifier-cc153ce6258b4e538d9fc7da5b5d0fe4), **[Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)](https://creativecommons.org/licenses/by-sa/4.0/)** (license confirmed by the project owner). Imported from the original Sketchfab ZIP; model is uniformly scaled and positioned in the reception scene. Geometry and original PBR textures are otherwise retained. If the original asset is further adapted and redistributed, its adapted material must remain under CC BY-SA 4.0 or a permitted compatible license. This game is a collection of separately credited assets and does not assert ownership of the model.
- **Desk Bell** — ClintonAbbott.Art, [Sketchfab original](https://sketchfab.com/3d-models/desk-bell-cc21b304c4bb4750bdde7a8fb538b116), CC BY 4.0.


## Oxygen — Backrooms environment and prop packs (CC0-1.0)

- **Backrooms Vol. 1** (modular corridors, walls, floors, ceilings, light fixtures):
  https://oxygen3d.itch.io/game-ready-backrooms-asset-pack-vol-1
- **Backrooms Vol. 2 (1k)** (interior props, office furniture and other details):
  https://oxygen3d.itch.io/game-ready-backrooms-asset-pack-vol-2
- Author: **Oxygen** (itch.io)
- License: **Creative Commons Zero v1.0 Universal (CC0-1.0)**;
  https://creativecommons.org/publicdomain/zero/1.0/

The original downloaded archives are retained in
`models/backrooms/oxygen/sources/`; the Godot-ready FBX/texture and GLB files
are in `models/backrooms/oxygen/vol1/` and `vol2/`. Exact source checksums,
import instructions and editor usage are recorded in
`models/backrooms/oxygen/README.md`. The CC0 license does not require credits,
but this attribution is retained for asset provenance.


## Menu interface icons and sounds (CC0 1.0)

- Nieobie, [Game Icon Pack v1.4](https://nieobie.itch.io/free-icons) ([SVG source v1.4](https://github.com/Nieobie/game-icon-pack/tree/v1.4/svg)), CC0. Selected SVG icons rendered white and tinted in the existing button theme.
- Kenney, [Interface Sounds](https://kenney.nl/assets/interface-sounds), CC0. `bong_001.ogg`, `confirmation_002.ogg`, `glass_006.ogg` copied byte-for-byte (matching user-provided Git blob hashes).


## The Flood water audio (CC0 1.0)

- **beskhu**, [water drop 1](https://freesound.org/people/beskhu/sounds/273870/), [water drop 2](https://freesound.org/people/beskhu/sounds/273869/), [water drop 3](https://freesound.org/people/beskhu/sounds/273868/).
- **Allan Legemaate (alegemaate)**, [Water Splashes](https://freesound.org/people/alegemaate/sounds/364701/).

All four sources are licensed [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
The supplied recordings were prepared as 44.1 kHz mono PCM16 WAV with trimmed
starts/tails, fades, high-pass filtering and level adjustment. Water Splashes
was cut into four independent footstep cues. Place the prepared files under
`audio/flood/` (water_drop_01..03.wav and water_step_01..04.wav).
The runtime uses the recordings when imported and falls back to procedural
audio if the optional asset pack has not yet been installed.

## The Escort animation library

Universal Animation Library (Standard), by Quaternius, CC0 1.0 Universal. Original: https://quaternius.com/packs/universalanimationlibrary.html. The user-supplied GLB is checksum-pinned and installed by tools/import_escort_animations.py. Only authored Idle, Walk_Formal and Jog_Fwd clips drive the Security Guard through Godot's native humanoid retargeting. The backward gait reverses the formal walk. The original character asset/license remains unchanged.


## Footstep recordings

- Dan Sfx — [Free Sound Pack 02 - Footsteps](https://cdansantana.itch.io/fsp2fs), royalty-free for commercial/noncommercial game use. The prepared WAVs are intended for use within Casino Anomaly, not as a standalone sound library. The source page does not expressly address standalone redistribution.
- bewagne — [Wet Soggy Squishy Footsteps](https://freesound.org/people/bewagne/sounds/187617/), [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/), cropped, mono-converted, filtered, faded, level-adjusted and mixed with carpet.
- patchytherat — [Squishy Footsteps to Walking in a Puddle](https://freesound.org/people/patchytherat/sounds/531571/), [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/), adapted and mixed with carpet.

See audio/README.md for the resource layout. Original synthetic fallback sounds remain available if resources are missing.
