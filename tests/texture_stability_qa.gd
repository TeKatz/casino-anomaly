extends SceneTree

# Moire / temporal texture shimmer regression coverage for Forward+.
func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("Casino texture stability QA: " + why)
    quit(1)

func _run() -> void:
    if ProjectSettings.get_setting("rendering/renderer/rendering_method") != "forward_plus":
        _fail("Forward+ is required for temporal antialiasing")
        return
    if not bool(ProjectSettings.get_setting("rendering/anti_aliasing/quality/use_taa", false)):
        _fail("Temporal AA is not enabled")
        return
    if int(ProjectSettings.get_setting("rendering/textures/default_filters/anisotropic_filtering_level", 0)) < 3:
        _fail("Anisotropic filtering must be at least 8x")
        return

    for path in [
        "floor_material.tres", "carpet_material.tres", "upper_wall_material.tres",
        "lower_wall_material.tres", "ceiling_material.tres", "pillar_material.tres",
        "bar_top_material.tres", "bar_side_material.tres", "roulette_wood_material.tres",
        "brown_planks_05_material.tres", "herringbone_parquet_material.tres",
        "bi_stretch_material.tres"
    ]:
        var mat: StandardMaterial3D = load("res://" + path) as StandardMaterial3D
        if mat == null or mat.albedo_texture == null:
            _fail("Texture material missing: " + path)
            return
        if mat.texture_filter != BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC:
            _fail("Texture filtering lacks mipmaps/anisotropy: " + path)
            return

    var scene: PackedScene = load("res://main.tscn")
    if scene == null:
        _fail("Casino main scene missing")
        return
    var hall: Node3D = scene.instantiate() as Node3D
    root.add_child(hall)
    await process_frame
    await process_frame
    var architecture: Node3D = hall.get_node_or_null("Architecture") as Node3D
    if architecture == null:
        _fail("Room architecture missing")
        return
    for part in ["OakMainWing", "OakWestWing", "MainCeiling",
        "WestCeiling", "NorthWestWall", "RightMainWall"]:
        var mesh: MeshInstance3D = architecture.get_node_or_null(part) as MeshInstance3D
        if mesh == null:
            _fail("Missing important PBR surface: " + part)
            return
        var mat: StandardMaterial3D = mesh.get_active_material(0) as StandardMaterial3D
        if mat == null or mat.texture_filter != BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC:
            _fail("Instantiated surface bypassed anisotropic mipmaps: " + part)
            return

    hall.queue_free()
    print("Casino Anomaly texture stability QA PASS")
    quit(0)
