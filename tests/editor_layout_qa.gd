extends SceneTree

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var packed := load("res://main.tscn") as PackedScene
    if packed == null:
        push_error("Editable main scene cannot be loaded")
        quit(1)
        return
    var room := packed.instantiate() as Node3D
    var sofa := room.get_node_or_null("ModelInteriors/LoungeSofa_01") as Node3D
    var slot := room.get_node_or_null("SlotMachines/Slot_02") as Node3D
    var table := room.get_node_or_null("GamingTables/Cards7") as Node3D
    var bar := room.get_node_or_null("CornerBar") as Node3D
    var lighting := room.get_node_or_null("Lighting") as Node3D
    if sofa == null or slot == null or table == null or bar == null or lighting == null:
        push_error("Editor placement nodes are missing")
        quit(1)
        return
    # The entire lighting collection is editable; the count is not fixed.
    var authored_lights := lighting.find_children("*", "OmniLight3D", true, false).size()
    if authored_lights < 1 or authored_lights > 24:
        push_error("Editor light configuration is empty or excessive")
        quit(1)
        return
    var desired_sofa := sofa.position + Vector3(0.37, 0, 0)
    var desired_slot := slot.position + Vector3(-0.41, 0, 0)
    var desired_table := table.position + Vector3(0, 0, 0.27)
    var desired_bar := bar.position + Vector3(0.2, 0, 0)
    sofa.position = desired_sofa
    slot.position = desired_slot
    table.position = desired_table
    bar.position = desired_bar
    root.add_child(room)
    await process_frame
    await process_frame
    await process_frame
    if not sofa.position.is_equal_approx(desired_sofa):
        push_error("Poly Haven anchor position was overwritten by generation")
        quit(1)
        return
    if not slot.position.is_equal_approx(desired_slot) or not table.position.is_equal_approx(desired_table):
        push_error("Slot/game table saved transforms were overwritten")
        quit(1)
        return
    if not bar.position.is_equal_approx(desired_bar):
        push_error("Editor bar transform was overwritten")
        quit(1)
        return
    if sofa.get_node_or_null("ModelSolidBody") == null:
        push_error("Moved sofa lost its gameplay collision")
        quit(1)
        return
    if slot.get_node_or_null("Body_Collision") == null:
        push_error("Moved slot lost its gameplay collision")
        quit(1)
        return
    print("Casino Anomaly editor layout QA PASS")
    quit(0)
