extends Node3D
## Pre-baked VoxelGI volumes for a rotated/streamed Casino Anomaly hall.
## No bake is performed at runtime. Exported builds only enable validated
## external VoxelGIData resources, never a blank or partially baked rig.
const BAKES := {
    "MainWingGI": "res://lighting/main_wing.res",
    "WestWingGI": "res://lighting/west_wing.res"
}

var baked_data_ready := false
var streaming_active := true


func _ready() -> void:
    streaming_active = not get_parent().has_meta("_streaming_standby")
    for item in get_children():
        if item is VoxelGI:
            (item as VoxelGI).visible = false
    var settings = get_node_or_null("/root/GameSettings")
    if settings != null:
        settings.options_changed.connect(_on_setting_changed)
    call_deferred("_load_baked_data")


func _load_baked_data() -> void:
    var loaded := 0
    for name in BAKES:
        var probe := get_node_or_null(name) as VoxelGI
        if probe == null:
            continue
        probe.visible = false
        var path: String = str(BAKES[name])
        if not ResourceLoader.exists(path):
            probe.data = null
            continue
        var baked := load(path) as VoxelGIData
        if baked == null or baked.get_octree_cells().is_empty() \
                or baked.get_data_cells().is_empty():
            probe.data = null
            continue
        probe.data = baked
        loaded += 1
    baked_data_ready = loaded == BAKES.size()
    if not baked_data_ready:
        # The shipped game must never claim that empty probes are doing GI.
        for item in get_children():
            if item is VoxelGI:
                (item as VoxelGI).visible = false
    _apply_visibility()


func _on_setting_changed(key: String) -> void:
    if key == "voxel_gi":
        _apply_visibility()


func set_streaming_active(enabled: bool) -> void:
    streaming_active = enabled
    _apply_visibility()


func _apply_visibility() -> void:
    var enabled := baked_data_ready and streaming_active
    var settings = get_node_or_null("/root/GameSettings")
    if settings != null:
        enabled = enabled and bool(settings.get_option("voxel_gi"))
    for item in get_children():
        if item is VoxelGI:
            (item as VoxelGI).visible = enabled


func has_complete_bake() -> bool:
    return baked_data_ready
