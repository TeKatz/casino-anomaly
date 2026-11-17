# Casino Anomaly

An independent, offline-first Windows 3D exploration game built with **Godot 4.5.1**. The first playable milestone is the original Poly Haven oak-plank floor test, now with a main menu and an optional independent Development updater.

## Development workflow

- `dev` is the active Development release branch.
- `main` is reserved for reviewed stable changes.
- A verified push to `dev` publishes a separate [Development release](https://github.com/TeKatz/casino-anomaly/releases/tag/development) in **this** repository.
- [Blackjack Casino](https://github.com/TeKatz/blackjack-casino) is a separate application and release channel.

## Playtest

Download and extract **every file** from the Windows Development ZIP. Launch `CasinoAnomaly.exe`. Select **Raum betreten** to walk over the 14 m × 14 m oak floor with WASD and mouse look. Press **Esc** to return to the menu. The menu can check for updates and installs newer verified Development packages through a separate Windows updater process. Network access is optional; offline gameplay works without it.

The current build deliberately contains no walls, casino furniture, anomaly mechanics, progression or casino application integration.

## Assets

The material is [Oak Wood Planks](https://polyhaven.com/a/oak_wood_planks) by Dimitrios Savva from [Poly Haven](https://polyhaven.com), CC0. Color, roughness and OpenGL normal maps are used at 2K resolution. Original files are downloaded and verified against pinned SHA-256 hashes by `tools/ensure_assets.py`.

## Release safety

Updates are a separate, opt-in action. The updater validates the Development manifest and the downloaded ZIP against SHA-256/size, stages it alongside the installation, waits for the running game to close, then exchanges directories with rollback on activation failure. Saves and settings belong in the Godot user-data directory, never under the replaceable install folder. Updates **do not** use Blackjack Casino's release or update endpoints.

The independent release is Windows x64 only. The updater is not available when running from the Godot editor.
