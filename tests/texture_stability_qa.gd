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
    # Headless Godot can discard GPU-only project settings during import.
    # The gameplay viewport is configured in hall.gd, while project.godot
    # itself is checked by CI before the Godot editor begins importing.

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
        # The lower-wall material is artist-edited in Godot and can use the
        # engine's normal trilinear-mipmap filtering. Do not silently replace
        # the artist's chosen filter; still reject non-mipmapped materials.
        if path == "lower_wall_material.tres":
            if mat.texture_filter != BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS \
                    and mat.texture_filter != BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC:
                _fail("Lower wall material lost mipmaps: " + path)
                return
        elif mat.texture_filter != BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC:
            _fail("Texture filtering lacks anisotropic mipmaps: " + path)
            return

    var scene: PackedScene = load("res://main.tscn")
    if scene == null:
        _fail("Casino main scene missing")
        return
    var hall: Node3D = scene.instantiate() as Node3D
    root.add_child(hall)
    await process_frame
    await process_frame
    if DisplayServer.get_name() != "headless":
        if not root.use_taa:
            _fail("Rendered casino viewport has temporal AA disabled")
            return
        if int(root.anisotropic_filtering_level) < 3:
            _fail("Rendered casino viewport is not using 8x anisotropy")
            return
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
