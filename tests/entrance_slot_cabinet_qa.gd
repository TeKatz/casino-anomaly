extends SceneTree
## A single editable cabinet prefab replaces all nine entrance placeholders.
## The optional imported retro hero can be removed by the artist.
## Positions, collisions and independent TopGlow materials must remain stable.

const CABINET_NAMES := [
    "Slot_02", "Slot_03", "Slot_04", "Slot_05", "Slot_06",
    "Slot_07", "Slot_08", "Slot_09", "Slot_10"
]


func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("Entrance cabinet QA: " + reason)
    quit(1)


func _run() -> void:
    var prefab := load("res://models/casino_furniture/heritage_slot_cabinet.tscn") as PackedScene
    var packed := load("res://gameplay/casino/main.tscn") as PackedScene
    if prefab == null or packed == null:
        _fail("Cabinet source or authored casino room missing")
        return
    var world := packed.instantiate() as Node3D
    var group := world.get_node_or_null("SlotMachines") as Node3D
    if group == null:
        _fail("No authored slot machines")
        return
    # Snapshot the saved artist transforms BEFORE _ready() and room streaming
    # have any chance to move/replace cabinets. A deliberate editor move of
    # Slot_10 (or any other cabinet) must not break this regression.
    var authored_transforms: Dictionary = {}
    for name in CABINET_NAMES:
        var saved := group.get_node_or_null(name) as Node3D
        if saved != null and saved.visible:
            authored_transforms[name] = saved.transform
    if authored_transforms.is_empty():
        _fail("Casino has no visible reworked entrance cabinets")
        return
    root.add_child(world)
    await process_frame
    await process_frame
    # The old Slot_01 is a hidden procedural placeholder. Its StaticBody3D
    # must NOT survive runtime loading, irrespective of whether the artist
    # kept or removed the separately imported retro hero.
    if group.get_node_or_null("Slot_01") != null:
        _fail("The hidden legacy slot source still blocks the entrance")
        return

    var glow_ids := {}
    for name in authored_transforms:
        var slot := group.get_node_or_null(name) as Node3D
        if slot == null or not slot.is_visible_in_tree() or not slot.has_meta("slot_cabinet_revision"):
            _fail("Authored cabinet disappeared or reverted to a placeholder: " + name)
            return
        var saved_transform: Transform3D = authored_transforms[name]
        if not slot.transform.is_equal_approx(saved_transform):
            _fail("Runtime overwrote the saved editor transform: " + name)
            return
        for detail in ["Body", "FootSocle", "BackCover", "WoodInlay_L",
                "WoodInlay_R", "CabinetContour_L", "CabinetContour_R",
                "MarqueeBody", "RoundedMarqueeTop", "MarqueeBrassFrame",
                "MachineTitle", "ReelOuterFrame", "ReelInset", "ReelGlass",
                "ButtonDesk", "ButtonDeskTop", "FrontLowerFascia",
                "Console_Collision", "Body_Collision", "CoinSlot", "TopGlow"]:
            if not slot.has_node(detail):
                _fail("Unfinished cabinet structure " + name + "/" + detail)
                return
        var title := slot.get_node("MachineTitle") as Label3D
        if title == null or title.text.is_empty():
            _fail("The illuminated marquees have no individual titles")
            return
        var chassis := slot.get_node("Body_Collision") as StaticBody3D
        var collider := chassis.get_node_or_null("BodyShape") as CollisionShape3D
        if collider == null or collider.disabled or not (collider.shape is BoxShape3D):
            _fail("Continuous cabinet chassis lost collision")
            return
        var stand := slot.get_node("Console_Collision") as StaticBody3D
        if stand.get_node_or_null("ConsoleShape") == null:
            _fail("Player control desk has no blocking physics")
            return
        var stool := slot.get_node_or_null("PlayerStool") as Node3D
        var recycled := stool.get_node_or_null("GamingStool") as Node3D if stool != null else null
        var stool_body := recycled.get_node_or_null("StoolBody") as StaticBody3D if recycled != null else null
        if stool == null or absf(stool.position.z - 1.24) > 0.001                 or stool_body == null or stool_body.get_node_or_null("StoolCollision") == null:
            _fail("The upholstered stool moved or lost its cylinder collision")
            return
        for i in range(3):
            var well := slot.get_node_or_null("ReelWell_%d" % i) as MeshInstance3D
            var glyph := slot.get_node_or_null("ReelGlyph_%d" % i) as Label3D
            if well == null or glyph == null or glyph.font_size > 35 or glyph.pixel_size > 0.003:
                _fail("A physical reel window or its symbol is missing")
                return
        var glow := slot.get_node("TopGlow") as MeshInstance3D
        var mat := glow.material_override as StandardMaterial3D
        if mat == null or not mat.emission_enabled:
            _fail("Slot marquee lighting no longer animates")
            return
        if glow_ids.has(mat.get_instance_id()):
            _fail("Different slot cabinets share an animated emissive material")
            return
        glow_ids[mat.get_instance_id()] = true

    world.queue_free()
    await process_frame
    print("Casino Anomaly entrance slot cabinet QA PASS")
    quit(0)
