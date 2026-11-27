@tool
extends VoxelGI
## Optional, external data; fresh clones work without a bake.
const Targets = preload("res://addons/casino_model_preview/voxel_bake_targets.gd")
const BAKE_PATH := Targets.BACKROOMS_OUTPUT

func _ready() -> void:
    if FileAccess.file_exists(BAKE_PATH):
        reload_baked_data()

func reload_baked_data() -> bool:
    if not FileAccess.file_exists(BAKE_PATH):
        return false
    # IGNORE avoids reusing stale GPU data after an external bake. A failed
    # load leaves the current probe data intact.
    var baked := ResourceLoader.load(BAKE_PATH, "VoxelGIData", ResourceLoader.CACHE_MODE_IGNORE) as VoxelGIData
    if baked == null or baked.get_bounds().size.length_squared() <= 0.0:
        return false
    if DisplayServer.get_name() != "headless":
        if baked.get_data_cells().is_empty() or baked.get_octree_cells().is_empty():
            return false
    # IGNORE does not register the loaded resource path. Explicitly retain the
    # external path so a later editor save cannot embed the voxel binary.
    baked.take_over_path(BAKE_PATH)
    data = baked
    return true
