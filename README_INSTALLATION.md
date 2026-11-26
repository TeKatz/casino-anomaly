# Silent Audience – optimized guest model pack

## Installation (Godot 4.5.1)

1. Update your `casino-anomaly` checkout: `git pull origin dev`.
2. Extract the **contents** of this ZIP into your local `casino-anomaly` repository root. The ZIP already contains `models/silent_audience/...`.
3. In Godot, open the project and allow the new glTF files to finish importing. If needed: Project > Reload Current Project.
4. In the game's Anomaly dev menu, launch `The Silent Audience` (`the_silent_audience`).

The connected GitHub write API cannot upload these large binary 3D files directly, so they are supplied as a reproducible asset pack rather than silently omitting them. The new `dev` branch scripts detect the five models and automatically activate the premium crowd; otherwise the existing croupier crowd remains as a fallback.

## Third-party license information

See `models/silent_audience/ATTRIBUTION.md` and the original `license.txt` in each model folder. The female CC BY-SA source remains CC BY-SA in this adapted pack; the independently-authored game code is not relicensed by this asset package.

## Asset changes

- Character rigs, skinned meshes, and their original materials were preserved.
- Opaque textures are resized and recompressed, alpha textures kept as PNG.
- Unused female morph-target arrays and its source animation were removed; the intact humanoid skeleton drives the new procedural sitting and standing.
- Guard gun and smoking meshes are not instantiated in the glTF scene; body and face remain.
- No source Sketchfab ZIP needs to be installed separately.
