@tool
extends Node3D
# Imported user-provided Sketchfab CC BY 4.0 models.
# Low-poly original placeholders only disappear after the corresponding
# complete glTF scene has been loaded and placed successfully.

const FOLDER := "res://models/sketchfab/"
const PREMIUM_ROULETTE = preload("res://models/casino_furniture/premium_roulette_table.tscn")
signal furniture_finalized
var assets: Dictionary = {}
var replaced_slots := 0
var replaced_roulette := 0
var replaced_blackjack := 0
var poker_props_placed := 0

# Temporary previews are ownerless; the optional authored group is saved in
# main.tscn and reused at runtime rather than spawning duplicate furniture.
@export var show_imported_models_in_editor := true:
    set(value):
        show_imported_models_in_editor = value
        if Engine.is_editor_hint() and is_inside_tree():
            call_deferred("_refresh_editor_preview")

var _editor_preview_root: Node3D = null
var _editor_hidden_sources: Dictionary = {}
var _baking_editor_models := false
const AUTHORED_GROUP := "EditableImportedModels"


func _ready() -> void:
    # Geometry for the GI bake stays authored and deliberately excludes
    # runtime furniture replacement (as before).
    if get_parent().has_meta("_baking_room"):
        return
    if Engine.is_editor_hint():
        call_deferred("_refresh_editor_preview")
    else:
        call_deferred("_populate")


func _exit_tree() -> void:
    if Engine.is_editor_hint():
        _clear_editor_preview()


func _refresh_editor_preview() -> void:
    _clear_editor_preview()
    if not Engine.is_editor_hint() or not is_inside_tree() \
            or not show_imported_models_in_editor or has_node(AUTHORED_GROUP):
        return
    _build_editor_preview()


func _build_editor_preview() -> Node3D:
    # Only populated after the final scene exists. The same _populate()
    # placement functions are used for editor and game, preventing model
    # scale, offset, or material drift while adjusting lighting.
    var hall := get_parent() as Node3D
    if hall == null or hall.has_meta("_baking_room") or has_node(AUTHORED_GROUP):
        return null
    _clear_editor_preview()
    var preview := Node3D.new()
    preview.name = "_EditorOnlyImportedFurniturePreview"
    add_child(preview, false, Node.INTERNAL_MODE_BACK)
    _editor_preview_root = preview
    _populate()
    return preview


func _clear_editor_preview() -> void:
    # Undo temporary visibility overrides before the authoring scene exits.
    for source in _editor_hidden_sources:
        if is_instance_valid(source):
            (source as Node3D).visible = bool(_editor_hidden_sources[source])
    _editor_hidden_sources.clear()
    if is_instance_valid(_editor_preview_root):
        remove_child(_editor_preview_root)
        _editor_preview_root.free()
    _editor_preview_root = null
    replaced_slots = 0
    replaced_roulette = 0
    replaced_blackjack = 0
    poker_props_placed = 0


## Convert transient Sketchfab previews into real, saved, selectable scene
## nodes. Called once from the editor's Project > Tools menu.
func bake_editable_models() -> bool:
    if not Engine.is_editor_hint() or not is_inside_tree():
        return false
    var hall := get_parent() as Node3D
    if hall == null or hall != get_tree().edited_scene_root:
        return false
    if has_node(AUTHORED_GROUP):
        return true
    for slug in ["retro_slot_machine", "roulette_table", "blackjack_table", "poker_set"]:
        if _load_scene(slug) == null:
            push_warning("Cannot make Sketchfab furniture editable: missing " + slug)
            return false
    if _load_scene("poker_set", "poker_props.glb") == null:
        return false
    _clear_editor_preview()
    var visibility_before := {}
    for source_path in ["SlotMachines/Slot_01",
            "GamingTables/Roulette2", "GamingTables/Roulette4",
            "GamingTables/Roulette6", "GamingTables/Blackjack1",
            "GamingTables/Blackjack3", "GamingTables/Blackjack5"]:
        var source := hall.get_node_or_null(source_path) as Node3D
        if source != null:
            visibility_before[source] = source.visible
    var group := Node3D.new()
    group.name = AUTHORED_GROUP
    add_child(group)
    group.owner = hall
    _editor_preview_root = group
    _baking_editor_models = true
    _populate()
    _baking_editor_models = false
    _editor_preview_root = null
    # Keep the original procedural placeholders hidden in the saved scene.
    _editor_hidden_sources.clear()
    _own_generated_nodes(group, hall)
    if replaced_slots != 1 or replaced_roulette != 3 or replaced_blackjack != 1:
        push_error("Sketchfab authoring incomplete; please check the imported assets")
        # Preserve the original scene if an asset failed half-way through.
        for source in visibility_before:
            if is_instance_valid(source):
                source.visible = visibility_before[source]
        group.queue_free()
        return false
    return true


func _own_generated_nodes(parent: Node, scene_root: Node) -> void:
    for child in parent.get_children():
        child.owner = scene_root
        # A packed glTF instance owns its own subscene. Never re-own the
        # imported mesh hierarchy: Godot saves it by its source scene path.
        if child.scene_file_path.is_empty():
            _own_generated_nodes(child, scene_root)


func _replacement_parent() -> Node3D:
    return _editor_preview_root if is_instance_valid(_editor_preview_root) else self


func _hide_or_replace_source(original: Node3D) -> void:
    if is_instance_valid(_editor_preview_root):
        if not _baking_editor_models and not _editor_hidden_sources.has(original):
            _editor_hidden_sources[original] = original.visible
        original.visible = false
    else:
        original.queue_free()


# Exercised from headless CI to validate preview meshes without opening the
# graphical Godot editor; never called by normal gameplay.
func create_editor_preview_for_test() -> Node3D:
    return _build_editor_preview()


func clear_editor_preview_for_test() -> void:
    _clear_editor_preview()


func has_active_editor_preview() -> bool:
    return is_instance_valid(_editor_preview_root)

func _load_scene(slug: String, filename: String = "scene.gltf") -> PackedScene:
    var path := FOLDER + slug + "/" + filename
    if not ResourceLoader.exists(path):
        return null
    if assets.has(path):
        return assets[path]
    var scene: PackedScene = load(path) as PackedScene
    if scene != null:
        assets[path] = scene
    else:
        push_warning("Sketchfab model import failed: " + path)
    return scene

func _mesh_bounds(scene_root: Node3D) -> AABB:
    var result := AABB()
    var found := false
    for candidate in scene_root.find_children("*", "MeshInstance3D", true, false):
        var part: MeshInstance3D = candidate as MeshInstance3D
        if part.mesh == null:
            continue
        var xform: Transform3D = scene_root.global_transform.affine_inverse() * part.global_transform
        var box: AABB = xform * part.get_aabb()
        result = result.merge(box) if found else box
        found = true
    return result

func _spawn(slug: String, label: String, spot: Vector3, max_width: float,
        max_height: float, yaw: float = 0.0, filename: String = "scene.gltf",
        add_collision: bool = true) -> Node3D:
    var packed := _load_scene(slug, filename)
    if packed == null:
        return null
    var wrapper := Node3D.new()
    wrapper.name = label
    wrapper.position = spot
    wrapper.rotation.y = yaw
    wrapper.set_meta("source_asset", slug)
    _replacement_parent().add_child(wrapper)
    var model: Node3D = packed.instantiate() as Node3D
    if model == null:
        wrapper.queue_free()
        push_error("Sketchfab model does not instantiate as a 3D node: " + slug)
        return null
    wrapper.add_child(model)
    var size: AABB = _mesh_bounds(model)
    if size.size.y < 0.001 or maxf(size.size.x, size.size.z) < 0.001:
        wrapper.queue_free()
        push_warning("Empty or unorientable imported Sketchfab mesh: " + slug)
        return null
    var factor: float = minf(max_width / maxf(size.size.x, size.size.z), max_height / size.size.y)
    model.scale = Vector3.ONE * factor
    model.position = Vector3(
        -(size.position.x + size.size.x * 0.5) * factor,
        -size.position.y * factor,
        -(size.position.z + size.size.z * 0.5) * factor
    )
    if add_collision and (_editor_preview_root == null or _baking_editor_models):
        var body := StaticBody3D.new()
        body.name = "FurnitureCollider"
        body.position.y = 0.829 if slug == "blackjack_table" else size.size.y * factor * 0.5
        var shape := CollisionShape3D.new()
        var box := BoxShape3D.new()
        if slug == "blackjack_table":
            # The old all-height bounding cube had a massive 0.326m margin,
            # obstructing empty air around the curved felt table. Only the
            # actual tabletop needs a broad collision plate.
            box.size = Vector3(2.48, 0.14, 1.48)
            box.margin = 0.012
        else:
            box.size = Vector3(
                maxf(size.size.x * factor, 0.25),
                maxf(size.size.y * factor, 0.25),
                maxf(size.size.z * factor, 0.25)
            )
        shape.shape = box
        body.add_child(shape)
        wrapper.add_child(body)
    return wrapper

func _finish(color: Color, roughness: float = 0.72, metallic: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    return material

func _block(parent: Node3D, label: String, pos: Vector3, size: Vector3,
        material: Material, solid: bool = false) -> MeshInstance3D:
    var mesh_node := MeshInstance3D.new()
    mesh_node.name = label
    var box := BoxMesh.new()
    box.size = size
    mesh_node.mesh = box
    mesh_node.position = pos
    mesh_node.material_override = material
    parent.add_child(mesh_node)
    if solid and (_editor_preview_root == null or _baking_editor_models):
        var body := StaticBody3D.new()
        body.name = label + "Collider"
        body.position = pos
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collision.shape = shape
        body.add_child(collision)
        parent.add_child(body)
    return mesh_node

func _retro_plinth(spot: Vector3) -> Node3D:
    # A modest raised and collision-equipped display platform, not an empty
    # floating grey plate. The actual imported mesh rests on its top.
    var stand := Node3D.new()
    stand.name = "RetroSlotPlinth"
    stand.position = spot
    _replacement_parent().add_child(stand)
    var mahogany := _finish(Color("#482820"), 0.56)
    var satin_brass := _finish(Color("#b39158"), 0.32, 0.65)
    var dark_top := _finish(Color("#282326"), 0.80)
    _block(stand, "PedestalBody", Vector3(0, 0.155, 0),
        Vector3(1.88, 0.31, 1.68), mahogany, true)
    _block(stand, "GoldInlay", Vector3(0, 0.314, 0),
        Vector3(1.90, 0.025, 1.70), satin_brass)
    _block(stand, "DisplaySurface", Vector3(0, 0.339, 0),
        Vector3(1.79, 0.025, 1.59), dark_top)
    return stand

func _roulette_table(spot: Vector3) -> Node3D:
    # Match the authored premium cabinet, even when older scenes need
    # the legacy Sketchfab editor preview / authoring conversion.
    # The wheel itself remains the separately imported Sketchfab model.
    var table := PREMIUM_ROULETTE.instantiate() as Node3D
    table.name = "RouletteTableCabinet"
    table.set_meta("furniture_kind", "roulette_table")
    table.position = spot
    _replacement_parent().add_child(table)
    if _editor_preview_root != null and not _baking_editor_models:
        # Preview is intentionally unsaved and must not bring physics into
        # the editor's preview scene. Authored and runtime models keep it.
        for collision in table.find_children("*", "CollisionObject3D", true, false):
            collision.get_parent().remove_child(collision)
            collision.free()
    return table

func _populate() -> void:
    var hall: Node3D = get_parent() as Node3D
    if hall == null:
        return
    # A level designer has authored the imported instances in main.tscn.
    # They are the source of truth; don't create copies on game startup.
    if not _baking_editor_models and has_node(AUTHORED_GROUP):
        # The editor conversion persists the imported geometry, so no
        # instances are spawned here. Keep the public replacement counters
        # consistent with the old runtime-generated path for gameplay, UI
        # and regression checks.
        replaced_slots = 0
        replaced_roulette = 0
        replaced_blackjack = 0
        poker_props_placed = 0
        var saved := get_node(AUTHORED_GROUP)
        for child in saved.get_children():
            match str(child.get_meta("source_asset", "")):
                "retro_slot_machine":
                    replaced_slots += 1
                "roulette_table":
                    replaced_roulette += 1
                "blackjack_table":
                    replaced_blackjack += 1
                "poker_set":
                    poker_props_placed += 1
        if not Engine.is_editor_hint():
            furniture_finalized.emit()
        return
    var slots: Node3D = hall.get_node_or_null("SlotMachines") as Node3D
    var tables: Node3D = hall.get_node_or_null("GamingTables") as Node3D
    if slots == null or tables == null:
        push_error("Casino room layout missing while importing Sketchfab furniture")
        return

    # The retro machine is ~500k triangles. Use ONE hero machine initially,
    # not ten copies: the existing prototypes stay in other places.
    var retro := slots.get_node_or_null("Slot_01") as Node3D
    if retro != null:
        # Place the imported slot on a raised mahogany display stand.
        var hero := _spawn("retro_slot_machine", "RetroSlotHero",
            retro.position + Vector3(0, 0.365, 0),
            1.42, 1.72, retro.rotation.y)
        if hero != null:
            _retro_plinth(retro.position)
            _hide_or_replace_source(retro)
            replaced_slots += 1

    for table in tables.get_children():
        if not (table is Node3D):
            continue
        var table_node: Node3D = table as Node3D
        var name_lower := table_node.name.to_lower()
        if name_lower.begins_with("roulette"):
            # Original Sketchfab download is a wheel with no tabletop.
            # Reduce its diameter to ~1 m and set it on the new 3.5 m
            # mahogany-and-felt roulette table with player collision.
            var replacement := _spawn("roulette_table", "SketchfabRoulette",
                table_node.position + Vector3(-1.02, 1.010, 0),
                1.28, 0.49, -PI * 0.5, "scene.gltf", false)
            if replacement != null:
                replacement.set_meta("placement_type", "roulette_wheel")
                _roulette_table(table_node.position)
                _hide_or_replace_source(table_node)
                replaced_roulette += 1
        elif name_lower.begins_with("blackjack"):
            var replacement := _spawn("blackjack_table", "SketchfabBlackjack",
                table_node.position, 2.60, 0.94, 0.0)
            if replacement != null:
                _hide_or_replace_source(table_node)
                replaced_blackjack += 1
                var cards := _spawn("poker_set", "PokerCardAndChips",
                    table_node.position + Vector3(0, 0.95, 0), 0.90, 0.20, 0.0,
                    "poker_props.glb", false)
                if cards != null:
                    poker_props_placed += 1
    # Atmosphere is built from the original authorable scene, but several
    # roulette/blackjack meshes are REPLACED here. Rebind shadow casters
    # once the actual imported meshes are in the tree.
    if _editor_preview_root != null:
        return
    furniture_finalized.emit()
    print("Sketchfab furniture imported: slots=", replaced_slots,
        ", roulette=", replaced_roulette, ", blackjack=", replaced_blackjack,
        ", poker props=", poker_props_placed)
