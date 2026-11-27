@tool
extends SceneTree
## One-time, editor-authoring conversion:
## retain the current exact transforms computed from imported glTF bounds,
## but persist every model and cabinet as native, editable .tscn children.
## Run AFTER all source meshes and textures were imported by Godot.
const DECOR_PATH := "res://gameplay/tutorial_decor.tscn"
const CONVERTED_MODELS := [
    "BooksWithMagnifier",
    "DeskBell",
    "VintageGramophone",
    "WallLightRightSconceA",
    "WallLightRightSconceB",
    "WallLightExitSconceLeft",
    "WallLightExitSconceRight"
]
const EXISTING_MODELS := [
    "WaitingLounge/UpholsteredSofa",
    "WaitingLounge/TeaTable",
    "EntranceDisplay/MarblePortraitBust",
    "Gallery/RightHistoricPainting",
    "Gallery/LeftHistoricPainting",
    "LightingAndCeiling/CentralChandelier"
]


func _initialize() -> void:
    call_deferred("_bake")


func _fail(message: String) -> void:
    push_error("Casino Anomaly editor conversion: " + message)
    quit(1)


func _save_authored(child: Node, authored_root: Node) -> void:
    # Children from regular scene instances belong to the imported source
    # scene, not to the tutorial. Register only the instance itself.
    child.owner = authored_root
    if child.scene_file_path != "":
        authored_root.set_editable_instance(child, true)
        return
    for descendant in child.get_children():
        _save_authored(descendant, authored_root)


func _bake() -> void:
    var original := load(DECOR_PATH) as PackedScene
    if original == null:
        _fail("Unable to open tutorial decoration scene")
        return
    var decor := original.instantiate() as Node3D
    if decor == null:
        _fail("Decoration root must be Node3D")
        return
    root.add_child(decor)
    # Scripted objects have been instantiated by the authored holder's _ready.
    await process_frame
    var holder := decor.get_node_or_null("UserSelectedProps") as Node3D
    if holder == null or holder.get_script() == null:
        _fail("Scene has already been converted or source mount is missing")
        return

    for name in CONVERTED_MODELS:
        var model := holder.get_node_or_null(name) as Node3D
        if model == null:
            _fail("Original Sketchfab model was not imported: " + name)
            return
        if model.scene_file_path == "":
            _fail("Source model is not a reusable imported scene: " + name)
            return
        _save_authored(model, decor)

    var cabinet := holder.get_node_or_null("GramophoneConsole") as StaticBody3D
    if cabinet == null:
        _fail("Missing grounded gramophone cabinet")
        return
    _save_authored(cabinet, decor)

    for path in EXISTING_MODELS:
        var model := decor.get_node_or_null(path) as Node3D
        if model == null or model.scene_file_path == "":
            _fail("Original furniture instance is not editable: " + path)
            return
        decor.set_editable_instance(model, true)

    # The old placeholders are already hidden by the import script.
    # Persist those visibility changes before removing dynamic authoring.
    for path in [
        "ReceptionDetails/ServiceBellBase",
        "ReceptionDetails/GuestRegisterCover",
        "LightingAndCeiling/RightSconceA/Shade",
        "LightingAndCeiling/ExitSconceLeft/Shade"
    ]:
        var old := decor.get_node_or_null(path) as VisualInstance3D
        if old == null or old.visible:
            _fail("Old placeholder was not replaced: " + path)
            return

    # Prevent a fresh, unsaved set of duplicates in the editor and on play.
    holder.set_script(null)
    var saved := PackedScene.new()
    var err := saved.pack(decor)
    if err != OK:
        _fail("Could not pack persistent editor nodes: " + str(err))
        return
    err = ResourceSaver.save(saved, DECOR_PATH)
    if err != OK:
        _fail("Could not save editable tutorial scene: " + str(err))
        return

    var saved_text := FileAccess.get_file_as_string(DECOR_PATH)
    if saved_text.contains("script = ExtResource(\"user_selected\")"):
        _fail("Runtime decorator is still attached after save")
        return
    for name in CONVERTED_MODELS:
        if not saved_text.contains("name=\"" + name + "\""):
            _fail("Model missing from saved editor scene: " + name)
            return
    if not saved_text.contains("GramophoneConsole"):
        _fail("Gramophone sideboard was not saved")
        return
    print("Casino Anomaly editable tutorial decoration bake PASS")
    decor.queue_free()
    await process_frame
    quit(0)
