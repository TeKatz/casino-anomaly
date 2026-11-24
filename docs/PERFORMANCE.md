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
