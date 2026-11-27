extends RefCounted
## Persisted physical keyboard/mouse bindings, plus standard gamepad mapping.
## Escape is always an emergency pause/back; dev shortcuts remain reserved.
const ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "sprint", "interact", "pause"]
const DEFAULTS := {
    "move_forward": [KEY_W, 0], "move_back": [KEY_S, 0],
    "move_left": [KEY_A, 0], "move_right": [KEY_D, 0],
    "sprint": [KEY_SHIFT, 0], "interact": [KEY_E, 0], "pause": [KEY_ESCAPE, 0]
}
const PAD_BUTTONS := {"sprint": JOY_BUTTON_LEFT_STICK, "interact": JOY_BUTTON_A, "pause": JOY_BUTTON_START}

static func valid(code: int, action: String) -> bool:
    if code == 0:
        return true
    if code < 0:
        return action != "pause" and -code in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]
    if code in [KEY_G, KEY_F9, KEY_F10, KEY_F11, KEY_F12, KEY_ALT, KEY_META, KEY_TAB, KEY_UNKNOWN]:
        return false
    if code == KEY_ESCAPE:
        return action == "pause"
    return not OS.get_keycode_string(code).is_empty()

static func sanitize(value: Variant) -> Dictionary:
    var result := DEFAULTS.duplicate(true)
    if not value is Dictionary:
        return result
    var used := {}
    # First validate the entire map. Corrupt/conflicting config falls back
    # to known playable defaults rather than silently stranding an action.
    for action in ACTIONS:
        var pair = value.get(action, DEFAULTS[action])
        if not pair is Array or pair.size() != 2:
            return DEFAULTS.duplicate(true)
        if not pair[0] is int or not pair[1] is int:
            return DEFAULTS.duplicate(true)
        var codes := [int(pair[0]), int(pair[1])]
        if codes == [0, 0]:
            return DEFAULTS.duplicate(true)
        for code in codes:
            if not valid(code, action) or (code != 0 and used.has(code)):
                return DEFAULTS.duplicate(true)
            if code != 0:
                used[code] = true
        result[action] = codes
    return result

static func token(event: InputEvent) -> int:
    if event is InputEventKey and event.pressed and not event.echo:
        return event.physical_keycode if event.physical_keycode != 0 else event.keycode
    if event is InputEventMouseButton and event.pressed:
        return -int(event.button_index)
    return 0

static func label(code: int) -> String:
    if code == 0:
        return "—"
    if code < 0:
        return "Mouse %d" % -code
    var local := code if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_keycode_from_physical(code)
    return OS.get_keycode_string(local if local != 0 else code)

static func apply(bindings: Dictionary, controller: bool, deadzone: float) -> void:
    for action in ACTIONS:
        var name := StringName("casino_" + action)
        if not InputMap.has_action(name):
            InputMap.add_action(name, deadzone)
        InputMap.action_set_deadzone(name, deadzone)
        Input.action_release(name)
        InputMap.action_erase_events(name)
        for code in bindings[action]:
            if code > 0:
                var key := InputEventKey.new()
                key.physical_keycode = code
                InputMap.action_add_event(name, key)
            elif code < 0:
                var button := InputEventMouseButton.new()
                button.button_index = -code
                InputMap.action_add_event(name, button)
        if controller and PAD_BUTTONS.has(action):
            var pad := InputEventJoypadButton.new()
            pad.button_index = PAD_BUTTONS[action]
            pad.device = -1
            InputMap.action_add_event(name, pad)
    for entry in [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0], ["move_forward", JOY_AXIS_LEFT_Y, -1.0], ["move_back", JOY_AXIS_LEFT_Y, 1.0], ["look_left", JOY_AXIS_RIGHT_X, -1.0], ["look_right", JOY_AXIS_RIGHT_X, 1.0], ["look_up", JOY_AXIS_RIGHT_Y, -1.0], ["look_down", JOY_AXIS_RIGHT_Y, 1.0]]:
        var name := StringName("casino_" + str(entry[0]))
        if not InputMap.has_action(name):
            InputMap.add_action(name, deadzone)
        if str(entry[0]).begins_with("look_"):
            Input.action_release(name)
            InputMap.action_erase_events(name)
        InputMap.action_set_deadzone(name, deadzone)
        if controller:
            var axis := InputEventJoypadMotion.new()
            axis.device = -1
            axis.axis = entry[1]
            axis.axis_value = entry[2]
            InputMap.action_add_event(name, axis)

static func pressed(event: InputEvent, action: String) -> bool:
    if event is InputEventKey and event.echo:
        return false
    if action == "pause" and event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
        return true
    if event.is_action_pressed("casino_" + action):
        return true
    # Synthetic QA events and some injected keyboards provide logical codes
    # only; real hardware input always uses the physical binding.
    if event is InputEventKey and event.pressed and event.physical_keycode == 0:
        var copy := event.duplicate() as InputEventKey
        copy.physical_keycode = event.keycode
        return copy.is_action_pressed("casino_" + action)
    return false

static func hint(context: Node) -> String:
    var settings := context.get_node_or_null("/root/GameSettings")
    if settings == null:
        return "E"
    var pair: Array = settings.call("get_option", "key_bindings")["interact"]
    if bool(settings.get_meta("_using_gamepad", false)) and bool(settings.call("get_option", "controller_enabled")):
        return "A"
    return label(int(pair[0]) if int(pair[0]) != 0 else int(pair[1]))

static func pref(context: Node, key: String, fallback: Variant) -> Variant:
    var settings := context.get_node_or_null("/root/GameSettings")
    return settings.call("get_option", key) if settings != null else fallback
