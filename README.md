# Casino Anomaly

Independent Godot 4.5.1 first-person prototype with a separate Windows updater and the dedicated [Development release](https://github.com/TeKatz/casino-anomaly/releases/tag/development).

## Room design pass

The current walkable hall is **L-shaped**: from the entrance it leads straight past slot-machine groups, turns **left** at the illuminated, wrap-around corner bar, and continues to the west wing with roulette/blackjack tables, a lounge and decorative exit doors. The red-and-gold bordered carpet forms an uninterrupted route through the corner. Players can step off the carpet to inspect furniture. This is a first spatial and lighting pass using handcrafted primitive placeholder meshes, not final models or anomaly gameplay.

The wooden floor retains the CC0 Poly Haven [Oak Wood Planks](https://polyhaven.com/a/oak_wood_planks) PBR material. The runner uses the CC0 [Quatrefoil Jacquard Fabric](https://polyhaven.com/a/quatrefoil_jacquard_fabric) PBR maps, with a muted finish and a dark/gold border. Original source maps and their pinned SHA-256 values are managed by `tools/ensure_assets.py`.

## Playtest and controls

Download and fully extract `casino-anomaly-win-x64.zip` from the Development release. Start `CasinoAnomaly.exe`, then select **Raum betreten**. WASD moves, mouse looks, and Esc returns to the menu. Exit doors are decorative for now; there is no anomaly detection or round progression.

The main menu checks this repo's Development channel for updates. It runs a separate Windows updater which verifies package SHA-256 and size, stages the download, and attempts recovery after failures. Game and updater are independent of Blackjack Casino. Save data belongs in the Godot user-data directory outside the install folder.

`dev` publishes Development releases; `main` remains the reviewed integration baseline. Verified Windows builds use Godot 4.5.1, .NET 10 for the updater, and original CC0 asset sources. No checkout, terminal, editor or asset import is required for playtesting.
