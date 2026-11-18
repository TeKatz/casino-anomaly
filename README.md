# Casino Anomaly

Independent Godot 4.5.1 first-person prototype with a separate Windows updater and the dedicated [Development release](https://github.com/TeKatz/casino-anomaly/releases/tag/development).

## Room design pass

The current walkable hall is **L-shaped**: from the entrance it leads straight past slot-machine groups, turns **left** at the illuminated, wrap-around corner bar, and continues into the second wing, now twice as long after the first visual playtest, with more roulette/blackjack tables, multiple lounge groups and decorative exit doors. The counter is now one continuous rounded-corner L shape, with seating on both sides; the standalone slot machine previously blocking the bar sightline was relocated. The red-and-gold bordered carpet forms an uninterrupted route through the corner. Players can step off the carpet to inspect furniture. This is a first spatial and lighting pass using handcrafted primitive placeholder meshes, not final models or anomaly gameplay.

The wooden floor retains the CC0 Poly Haven [Oak Wood Planks](https://polyhaven.com/a/oak_wood_planks) PBR material. The runner uses the CC0 [Quatrefoil Jacquard Fabric](https://polyhaven.com/a/quatrefoil_jacquard_fabric) PBR maps, with a muted finish and a dark/gold border. Original source maps and their pinned SHA-256 values are managed by `tools/ensure_assets.py`.

## Playtest and controls

Download and fully extract `casino-anomaly-win-x64.zip` from the Development release. Start `CasinoAnomaly.exe`, then select **Raum betreten**. WASD moves, mouse looks, and Esc returns to the menu. Exit doors are decorative for now; there is no anomaly detection or round progression.

The main menu checks this repo's Development channel for updates. It runs a separate Windows updater which verifies package SHA-256 and size, stages the download, and attempts recovery after failures. Game and updater are independent of Blackjack Casino. Save data belongs in the Godot user-data directory outside the install folder.

`dev` publishes Development releases; `main` remains the reviewed integration baseline. Verified Windows builds use Godot 4.5.1, .NET 10 for the updater, and original CC0 asset sources. No checkout, terminal, editor or asset import is required for playtesting.

## Poly Haven interior pass

The next development pass loads **10 original CC0 Poly Haven 3D models** as reusable imported glTF scenes: both chandeliers, brass candleholders, marble bust, framed painting, CCTV camera, wine bottles, round bar chairs, coffee cart and wooden cabinet. They are integrated into the existing L-shaped hall and the wraparound corner bar, with low-cost non-shadow-casting practical lights, basic pedestrian collision for furniture and data-driven automatic alignment. Imported models use original source geometry and mostly 1K PBR texture maps to keep performance and download size reasonable. Asset manifests and SHA-256 checks are stored under `models/`, with licensing recorded in [ASSET_CREDITS.md](ASSET_CREDITS.md). Further visual tweaking will follow on-device playtests.

## Interior visual QA pass

Fixed seven issues from in-game screenshots: (1) both marble busts face the walkable hall; (2) stools are taller and all have matching burgundy upholstery; (3) grouped labelled bottles were removed from the customer-facing counter and moved to a dedicated shelf spot; (4) coffee cart rotated to face the room; (5) the wide donor sideboard rests on a wood base and has geometry-sized collision; (6) floor meshes now generate tangents required by their PBR normalmaps, restoring proper wood/jacquard lighting, with a subtle burgundy lift and more legible textile pattern; (7) individual tall candleholders are extracted from the three-piece glTF, with only one larger candlestick per table. No new third-party assets were added.

## Spatial QA pass (after dev.10)

The player-reported defects were fixed in the scene itself: no procedural stools behind the Poly Haven bar stools, greater spacing at the L-shaped counter, the bar and its colliders shifted away from the wall pilasters, physical collision on every architectural pillar, coffee cart in a free wall bay, topiary separated from the sofas, and no luminous spheres on lounge tables. The previously disabled ambient-light source has been replaced with color ambient lighting; both material meshes now render from either side. A new spatial regression test validates floor materials, pillar bodies, furniture spacing and lighting before release.

## Sketchfab casino objects (feature branch)

The uploaded models have been audited; the five original Sketchfab glTF
archives include CC BY 4.0 license files and author attribution. For the
first pass, the scene attempts to replace three roulette-table prototypes,
one blackjack table and one retro slot-machine prototype; the poker set
is reduced to a compact, approximately 27k-triangle cards/chips/dice display.
The original *Casino_2* file is a whole room, so it has its own model-preview
button instead of overlapping the established L-shaped casino.

To complete the binary upload to GitHub, place the five verified, compressed
ZIP files from the Sketchfab asset package in `sketchfab_drop/` on
`feature/sketchfab-casino-assets`. They are individually under the 25 MiB
GitHub web-upload limit. Checksums are pinned in `catalog.json`.
The CI workflow extracts them before Godot import; no Godot authoring or
manual asset processing is required. The `dev` release workflow is not
modified until this feature branch is validated and merged.
