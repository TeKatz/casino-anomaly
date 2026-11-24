@tool
extends Node3D
## Pre-baked VoxelGI volumes for a rotated/streamed Casino Anomaly hall.
## No bake is performed at runtime. Exported builds only enable validated
## external VoxelGIData resources, never a blank or partially baked rig.
const RuntimeCache = preload("res://gameplay/runtime_asset_cache.gd")
const BAKES := {
    "MainWingGI": "res://lighting/main_wing.res",
    "WestWingGI": "res://lighting/west_wing.res"
}

var baked_data_ready := false
var streaming_active := true


func _ready() -> void:
    _ensure_volumes()
    # The editor has no live run or user graphics state. Always preview
    # validated baked GI there. In game, keep the streaming and settings
    # gates exactly as before.
    streaming_active = true if Engine.is_editor_hint() else \
            not get_parent().has_meta("_streaming_standby")
    for item in get_children():
        if item is VoxelGI:
            (item as VoxelGI).visible = false
    if not Engine.is_editor_hint():
        var settings = get_node_or_null("/root/GameSettings")
        if settings != null:
            settings.options_changed.connect(_on_setting_changed)
    call_deferred("_load_baked_data")


func _ensure_volumes() -> void:
    _ensure_volume("MainWingGI", Vector3(0, 3.15, 0.5),
        Vector3(12.8, 7.6, 27.9))
    _ensure_volume("WestWingGI", Vector3(-26, 3.15, -6.5),
        Vector3(40.8, 7.6, 13.7))


func _ensure_volume(label: String, center: Vector3, extents: Vector3) -> void:
    if has_node(label):
        return
    var volume := VoxelGI.new()
    volume.name = label
    volume.position = center
    volume.size = extents
    volume.subdiv = VoxelGI.SUBDIV_128
    volume.visible = false
    add_child(volume)


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
        if not RuntimeCache.valid_gi(baked):
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
    if not Engine.is_editor_hint():
        var settings = get_node_or_null("/root/GameSettings")
        if settings != null:
            enabled = enabled and bool(settings.get_option("voxel_gi"))
    for item in get_children():
        if item is VoxelGI:
            (item as VoxelGI).visible = enabled
    # In the editor the decorative atmosphere script is intentionally not
    # running. Never trigger its gameplay-only fallback synchronization.
    if not Engine.is_editor_hint():
        var atmosphere := get_parent().get_node_or_null("CasinoAtmosphere") as Node3D
        if atmosphere != null and atmosphere.has_method("_sync_hybrid_lights"):
            atmosphere.call_deferred("_sync_hybrid_lights")


func has_complete_bake() -> bool:
    return baked_data_ready
