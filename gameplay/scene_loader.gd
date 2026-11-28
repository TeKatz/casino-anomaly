extends CanvasLayer
## Persistent transition overlay. We render a complete UI frame *before*
## starting threaded resource loading and before the potentially expensive
## main-thread scene instantiation. This leaves a useful image on screen
## rather than making Windows appear to have frozen.
signal transition_failed(target_path: String)

const Controls = preload("res://gameplay/input_bindings.gd")
const FitCenter = preload("res://ui/fit_centered_panel.gd")
const Loc = preload("res://gameplay/localization.gd")
const ButtonSkin = preload("res://ui/luminous_button.gd")
const SCENES := ["res://gameplay/tutorial.tscn", "res://main.tscn"]
const BACKGROUND_SHADER = preload("res://ui/abstract_menu.gdshader")

var overlay: Control
var status_label: Label
var progress_label: Label
var stage_label: Label
var progress_bar: ProgressBar
var mark: TextureRect
var failure_buttons: HBoxContainer
var retry_button: Button
var return_button: Button
var target_path := ""
var finish_tutorial := false
var active := false
var requested := false
var committing := false
var failed := false
var elapsed := 0.0
var display_progress := 0.0
var _last_journal_progress := -1


func _trace(event: String, details: Dictionary = {}) -> void:
    var journal := get_node_or_null("/root/CrashJournal")
    if journal != null:
        var payload := details.duplicate()
        payload["target"] = target_path
        payload["progress_percent"] = int(round(display_progress * 100.0))
        journal.call("record", event, payload)


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 110
    _build_screen()
    var options = get_node_or_null("/root/GameSettings")
    if options != null:
        options.options_changed.connect(_on_option_changed)


func _build_screen() -> void:
    overlay = Control.new()
    overlay.name = "LoadingOverlay"
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.visible = false
    add_child(overlay)

    var background := ColorRect.new()
    background.name = "Background"
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.color = Color.WHITE
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var shader_material := ShaderMaterial.new()
    shader_material.shader = BACKGROUND_SHADER
    background.material = shader_material
    overlay.add_child(background)

    var wash := ColorRect.new()
    wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    wash.color = Color("#07111c", 0.55)
    wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(wash)

    var center := FitCenter.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(center)

    var panel := PanelContainer.new()
    panel.name = "LoadingCard"
    panel.custom_minimum_size = Vector2(560, 448)
    var card := StyleBoxFlat.new()
    card.bg_color = Color("#101c2b", 0.88)
    card.border_color = Color("#64788a", 0.64)
    card.set_border_width_all(1)
    card.set_corner_radius_all(22)
    card.shadow_color = Color(0.0, 0.0, 0.0, 0.60)
    card.shadow_size = 26
    panel.add_theme_stylebox_override("panel", card)
    center.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 48)
    margin.add_theme_constant_override("margin_right", 48)
    margin.add_theme_constant_override("margin_top", 34)
    margin.add_theme_constant_override("margin_bottom", 34)
    panel.add_child(margin)

    var stack := VBoxContainer.new()
    stack.alignment = BoxContainer.ALIGNMENT_CENTER
    stack.add_theme_constant_override("separation", 13)
    margin.add_child(stack)

    mark = TextureRect.new()
    mark.name = "BrandMark"
    mark.custom_minimum_size = Vector2(144, 144)
    mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
    mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    mark.texture = load("res://branding/casino_anomaly_emblem.png") as Texture2D
    stack.add_child(mark)

    var heading := TextureRect.new()
    heading.name = "BrandWordmark"
    heading.custom_minimum_size = Vector2(300, 39)
    heading.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    heading.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    heading.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    heading.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
    heading.texture = load("res://branding/casino_anomaly_wordmark.png") as Texture2D
    stack.add_child(heading)

    var separator := Control.new()
    separator.custom_minimum_size.y = 4.0
    stack.add_child(separator)

    status_label = Label.new()
    status_label.name = "LoadingStatus"
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 18)
    status_label.add_theme_color_override("font_color", Color("#bcd2df"))
    stack.add_child(status_label)

    progress_bar = ProgressBar.new()
    progress_bar.name = "ResourceProgress"
    progress_bar.custom_minimum_size = Vector2(410, 12)
    progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    progress_bar.show_percentage = false
    var track := StyleBoxFlat.new()
    track.bg_color = Color("#233447")
    track.set_corner_radius_all(7)
    progress_bar.add_theme_stylebox_override("background", track)
    var fill := StyleBoxFlat.new()
    fill.bg_color = Color("#95bbcb")
    fill.set_corner_radius_all(7)
    progress_bar.add_theme_stylebox_override("fill", fill)
    stack.add_child(progress_bar)

    progress_label = Label.new()
    progress_label.name = "ProgressLabel"
    progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    progress_label.add_theme_font_size_override("font_size", 13)
    progress_label.add_theme_color_override("font_color", Color("#97acbb"))
    stack.add_child(progress_label)

    stage_label = Label.new()
    stage_label.name = "LoadingHint"
    stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stage_label.add_theme_font_size_override("font_size", 13)
    stage_label.add_theme_color_override("font_color", Color("#7e99ac"))
    stack.add_child(stage_label)

    failure_buttons = HBoxContainer.new()
    failure_buttons.add_theme_constant_override("separation", 16)
    failure_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    failure_buttons.visible = false
    stack.add_child(failure_buttons)

    retry_button = ButtonSkin.new()
    retry_button.custom_minimum_size = Vector2(166, 46)
    retry_button.pressed.connect(_retry)
    failure_buttons.add_child(retry_button)
    return_button = ButtonSkin.new()
    return_button.custom_minimum_size = Vector2(166, 46)
    return_button.pressed.connect(_dismiss_error)
    failure_buttons.add_child(return_button)
    _refresh_locale()


func travel_to(path: String, complete_intro: bool = false) -> bool:
    if active or not SCENES.has(path):
        return false
    active = true
    failed = false
    committing = false
    requested = false
    target_path = path
    finish_tutorial = complete_intro
    elapsed = 0.0
    display_progress = 0.0
    _last_journal_progress = -1
    _trace("load_overlay_requested", {"complete_intro": complete_intro})
    progress_bar.value = 0.0
    progress_label.text = "0%"
    overlay.modulate.a = 1.0
    overlay.visible = true
    failure_buttons.visible = false
    _refresh_locale()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    # A newly visible CanvasLayer needs a rendered frame before Godot begins
    # loading the very large authored main.tscn and its dependencies.
    call_deferred("_begin_loading")
    return true


func _use_parallel_dependencies(path: String, complete_intro: bool, headless: bool) -> bool:
    # Preserve the existing headless workaround and other loading routes.
    return not headless and not (path == "res://main.tscn" and complete_intro)


func _begin_loading() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    if not active or failed:
        return
    # The confirmed native crash happened after the tutorial-to-casino
    # threaded request succeeded. Serialize its dependency workers as a
    # targeted mitigation; the request itself remains asynchronous.
    var use_sub_threads := _use_parallel_dependencies(target_path, finish_tutorial, DisplayServer.get_name() == "headless")
    _trace("load_threaded_request_begin", {"parallel_dependencies": use_sub_threads})
    var err := ResourceLoader.load_threaded_request(target_path, "PackedScene", use_sub_threads)
    _trace("load_threaded_request_returned", {"error": err})
    if err != OK:
        _fail("ResourceLoader request error: %s" % err)
        return
    requested = true


func _process(delta: float) -> void:
    if not active:
        return
    elapsed += delta
    if not failed:
        mark.modulate.a = 0.84 + 0.16 * sin(elapsed * 2.5) if bool(Controls.pref(self, "loading_motion", true)) and not bool(Controls.pref(self, "reduced_menu_motion", false)) else 1.0
    if not requested or failed or committing:
        return
    var progress: Array = []
    var status := ResourceLoader.load_threaded_get_status(target_path, progress)
    match status:
        ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            if not progress.is_empty():
                display_progress = maxf(display_progress, clampf(float(progress[0]), 0.0, 1.0) * 0.90)
                progress_bar.value = display_progress * 100.0
                progress_label.text = "%d%%" % int(round(display_progress * 100.0))
                var bucket := int(display_progress * 10.0)
                if bucket > _last_journal_progress:
                    _last_journal_progress = bucket
                    _trace("load_progress")
        ResourceLoader.THREAD_LOAD_LOADED:
            requested = false
            committing = true
            display_progress = 0.94
            _trace("load_resources_ready")
            progress_bar.value = 94.0
            progress_label.text = "94%"
            status_label.text = Loc.t("loading.initializing", self)
            call_deferred("_commit_scene")
        ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            _fail("ResourceLoader failed for " + target_path)


func _commit_scene() -> void:
    # Show the 'initializing' phase before the main thread instantiates
    # geometry, GI, imported meshes, and navigation/collision structures.
    await get_tree().process_frame
    await get_tree().process_frame
    if not active or failed:
        return
    _trace("load_get_packed_begin")
    var packed := ResourceLoader.load_threaded_get(target_path) as PackedScene
    _trace("load_get_packed_returned", {"valid": packed != null})
    if packed == null:
        _fail("Target is not a PackedScene: " + target_path)
        return
    _trace("load_activate_scene_begin")
    var error := get_tree().change_scene_to_packed(packed)
    _trace("load_activate_scene_returned", {"error": error})
    if error != OK:
        _fail("Scene activation error: %s" % error)
        return
    # The scene change is deferred; commit the flag only after activation
    # was accepted, but before the casino controller prepares round one.
    if finish_tutorial:
        var run_state = get_node_or_null("/root/LoopState")
        if run_state != null:
            _trace("load_complete_tutorial_begin")
            run_state.complete_tutorial()
            _trace("load_complete_tutorial_returned")
    await get_tree().process_frame
    var first_scene := get_tree().current_scene
    _trace("load_first_frame_after_activation", {"current_scene": first_scene.scene_file_path if first_scene != null else ""})
    await get_tree().process_frame
    var second_scene := get_tree().current_scene
    _trace("load_second_frame_after_activation", {"current_scene": second_scene.scene_file_path if second_scene != null else ""})
    display_progress = 1.0
    _trace("load_scene_ready")
    progress_bar.value = 100.0
    progress_label.text = "100%"
    status_label.text = Loc.t("loading.ready", self)
    var fade := create_tween()
    fade.tween_property(overlay, "modulate:a", 0.0, 0.26)
    fade.tween_callback(_finish)


func _finish() -> void:
    _trace("load_overlay_closed", {"failed": failed})
    overlay.visible = false
    overlay.modulate.a = 1.0
    active = false
    committing = false
    requested = false
    failed = false
    target_path = ""


func _fail(detail: String) -> void:
    _trace("load_failed", {"error": detail})
    push_warning("Casino Anomaly scene loading failed: " + detail)
    requested = false
    committing = false
    failed = true
    status_label.text = Loc.t("loading.error", self)
    stage_label.text = Loc.t("loading.retry_hint", self)
    progress_label.text = ""
    failure_buttons.visible = true
    transition_failed.emit(target_path)


func _retry() -> void:
    if not failed:
        return
    var path := target_path
    var complete_intro := finish_tutorial
    _finish()
    travel_to(path, complete_intro)


func _dismiss_error() -> void:
    if not failed:
        return
    _finish()
    if get_tree().current_scene is Node3D:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    else:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_option_changed(key: String) -> void:
    if key == "language":
        _refresh_locale()


func _refresh_locale() -> void:
    if status_label == null:
        return
    if failed:
        status_label.text = Loc.t("loading.error", self)
        stage_label.text = Loc.t("loading.retry_hint", self)
    elif committing:
        status_label.text = Loc.t("loading.initializing", self)
        stage_label.text = Loc.t("loading.hint", self)
    else:
        status_label.text = Loc.t("loading.resources", self)
        stage_label.text = Loc.t("loading.hint", self)
    retry_button.text = Loc.t("loading.retry", self)
    return_button.text = Loc.t("loading.return", self)
