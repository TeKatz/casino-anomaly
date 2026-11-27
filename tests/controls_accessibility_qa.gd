extends SceneTree
const Controls = preload("res://gameplay/input_bindings.gd")

func _initialize() -> void:
    call_deferred("_run")

func fail(message: String) -> void:
    push_error("Controls and accessibility QA: " + message)
    quit(1)

func _run() -> void:
    var settings = root.get_node("GameSettings")
    var saved: Dictionary = settings.options.duplicate(true)
    settings.reset_category(2)
    if settings.rebind("interact", 1, KEY_W) != "move_forward":
        fail("Duplicate key conflict not rejected")
        return
    if settings.rebind("interact", 0, KEY_F9) != "reserved":
        fail("Developer key is not protected")
        return
    if settings.rebind("interact", 0, KEY_F) != "" or settings.rebind("interact", 1, -MOUSE_BUTTON_RIGHT) != "":
        fail("Keyboard and secondary mouse binding not applied")
        return
    var key := InputEventKey.new()
    key.keycode = KEY_F
    key.pressed = true
    var mouse := InputEventMouseButton.new()
    mouse.button_index = MOUSE_BUTTON_RIGHT
    mouse.pressed = true
    if not Controls.pressed(key, "interact") or not Controls.pressed(mouse, "interact"):
        fail("InputMap does not use saved bindings")
        return
    settings.save_options()
    settings.load_options()
    if settings.get_option("key_bindings")["interact"] != [KEY_F, -MOUSE_BUTTON_RIGHT]:
        fail("Bindings did not persist")
        return
    settings.reset_category(2)
    key.keycode = KEY_E
    if not Controls.pressed(key, "interact"):
        fail("Reset category did not restore defaults")
        return
    var pad := InputEventJoypadButton.new()
    pad.button_index = JOY_BUTTON_A
    pad.pressed = true
    if not Controls.pressed(pad, "interact"):
        fail("Gamepad action missing")
        return
    settings.set_option("controller_enabled", false)
    if Controls.pressed(pad, "interact"):
        fail("Controller disabled preference ignored")
        return
    settings.set_option("sfx_volume", 0.9)
    settings.set_option("ambience_volume", 0.0)
    if not AudioServer.is_bus_mute(AudioServer.get_bus_index("AMBIENCE")) or AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")):
        fail("Ambience channel is not independent")
        return
    settings.set_option("horror_volume", 1.0)
    settings.set_option("reduced_horror_audio", true)
    if not is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("HORROR")), linear_to_db(0.35)):
        fail("Reduced horror mix not applied")
        return
    if AudioServer.get_bus_send(AudioServer.get_bus_index("FOOTSTEP")) != "WORLD" or AudioServer.get_bus_index("WORLD") >= AudioServer.get_bus_index("FOOTSTEP"):
        fail("World audio routing is out of order")
        return
    settings.set_option("mono_audio", true)
    if not settings.master_effects.has("mono"):
        fail("Mono audio effect missing")
        return
    settings.set_option("mono_audio", false)
    if settings.master_effects.has("mono"):
        fail("Mono effect did not release")
        return
    var label := Label.new()
    label.add_theme_font_size_override("font_size", 20)
    root.add_child(label)
    settings.set_option("ui_text_size", "large")
    settings.set_option("high_contrast_ui", true)
    if label.get_theme_font_size("font_size") != 23 or label.get_theme_color("font_color") != Color.WHITE:
        fail("Accessibility text changes missing")
        return
    settings.set_option("ui_scale", 1.25)
    if not is_equal_approx(root.content_scale_factor, 1.25):
        fail("UI scale not applied")
        return
    settings.reset_category(5)
    if label.get_theme_font_size("font_size") != 20 or not is_equal_approx(root.content_scale_factor, 1.0):
        fail("Accessibility reset did not restore defaults")
        return
    label.free()
    settings._change(saved, true)
    settings.save_options()
    print("Casino Anomaly controls audio and accessibility QA PASS")
    quit(0)
