# The Silent Audience – optimized 5-model pack

The five user-selected Sketchfab models are distributed separately as **silent_audience_models_optimized.zip**. The scripts on dev automatically use them when all five imported glTFs are available, otherwise the original tested low-poly croupier remains a fallback.

Install:
1. Unzip the pack into the **repository root**, merging its models/ directory.
2. Launch Godot 4.5.1 and let the imported glTFs finish processing.
3. Play major event **The Silent Audience** (id: the_silent_audience).

The ZIP is prepared from five user-supplied archives, with texture downsampling and removal of unused morph buffers from the female model. No network downloads take place during gameplay. See ASSET_CREDITS.md and each bundled model/license.txt for source credits. The adapted Realistic Female remains **CC BY-SA 4.0**; the remaining four characters are **CC BY 4.0**.

The runtime maintains the slow offscreen character appearances, ambient sound decay and room-local teardown. The premium version has distinct rigs and non-looping seated skeletal idles. The finale uses in-place skeletal transitions and keeps bar/table guests seated if rising would intersect the furniture, instead of silently sliding them through colliders.

When improving visual polish, check the actual Godot viewport (especially face materials, eye transparency and seated alignment). CI checks script loading and no-horizontal-root-motion using the existing rig, but does not render the five private binary assets.
