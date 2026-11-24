# Runtime performance (phases 1–2)

Runtime asset cache: bounded FIFO references (32 packed scenes, 128 entries per
geometry/bounds category, 16 weak GI validation entries). Live nodes own their
own transforms, materials and collision state. Cache-only references are
released when entering the main menu. The editor bypasses all shared
cache entries. Imported bounds are cached only for newly instantiated source
models, keyed by source path and variant; authored overrides remain measured.
Portal meshes and shapes are immutable after construction. The fixed dust mesh
and material may be shared; no generic mutable material deduplication is used.

The existing streaming diagnostic hotkey (Ctrl+F9) also logs
p99 frame time per sampling window, engine static/video memory, live nodes,
resources, orphan count and cache counters. Engine-reported static/video memory
is not OS process RSS or a complete GPU timing measurement. The sampling array
is bounded. Compare identical settings, driver and route before/after, including
many loops and a Backrooms return. Headless QA verifies correctness and cache
bounds, not real GPU FPS. No FPS gain is claimed without measurement.

The Windows export excludes QA scripts and raw asset-source ZIP archives;
imported assets, JSON catalogues, authored scenes, editor source files and
baked lighting remain in the project. No existing scene or import is rewritten.

## Phases 3–4: scene and rendering

Graphics settings use a per-type live node index, with removal on SceneTree
exit. Material sampler changes on newly attached meshes are batched, and
each shared material is updated once per pass. Lighting, environment and UI
deferred initialization are deliberately not reordered. The three streaming
phases, thresholds, choice labels, and GI/reflective prewarm contract stay
unchanged. Foliage only skips updates while a staged room is still behind
the opaque connector. The elapsed clock continues and transforms are
restored at prewarm. Menu collision generation is skipped for imported
model colliders, and existing collision layers are disabled before entry.
The menu still uses the actual artist-edited casino.

Structural box occluders and identical runtime-generated velvet stool
cushions share render resources. Every instance retains its individual node
and transform (including the stool anomaly); editor mode bypasses the cache.
This enables existing Forward+ automatic instancing without combining
anomaly targets or changing visibility granularity. Manual MultiMesh
replacement is not enabled without measured draw-call benefit and visual QA.

Run the asset inventory after restoring/extracting assets:
`python tools/audit_render_assets.py > render-asset-audit.json`.
The development workflow also uploads the JSON report. It reports source
triangles, mesh-node triangle counts, surfaces, materials, texture
dimensions/bytes, duplicate source hashes and relevant import settings.
No geometry or texture is resized or rewritten. Sampled existing glTF
sidecars already generate LODs and shadow meshes. Example source counts:
chess set 76,920 triangles (37 primitives), chandelier 01 26,860,
chandelier 02 21,514, monstera 9,310, sofa 2,728. These are not GPU frame
measurements. Review full extracted asset inventory and visual comparisons
before changing LOD or texture compression.

Optional developer-only GPU dust comparison: launch the game with
`-- --gpu-dust` after the usual executable/engine arguments. Existing
particle quality options apply to both backends. The default remains
12 CPU emitters with unchanged appearance and particle budget; headless
QA also uses CPU. Compare visually and measure on the target GPU before
considering a default backend switch. GPU particle motion is not
guaranteed identical to CPU simulation.
