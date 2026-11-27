extends ColorRect
## Opaque startup cover. The first boot shows the brand; later returns
## use only a brief dark transition, not a repeated creator splash.
signal finished
const Controls = preload("res://gameplay/input_bindings.gd")

var active := false
var closing := false
var earliest_reveal := 0
var fade: Tween
@onready var content: VBoxContainer = $Center/Content

func begin(first_launch: bool) -> void:
    if active:
        return
    active = true
    closing = false
    modulate.a = 1.0
    content.visible = first_launch
    content.modulate.a = 0.0
    earliest_reveal = Time.get_ticks_msec() + (1600 if first_launch else 180)
    show()
    move_to_front()
    set_process_input(true)
    if first_launch:
        var settings := get_node_or_null("/root/GameSettings")
        if settings != null and str(settings.get_option("language")) == "de":
            $Center/Content/Creator.text = "Ein Spiel von TeKatz"
        fade = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        fade.tween_property(content, "modulate:a", 1.0, 0.0 if bool(Controls.pref(self, "reduced_menu_motion", false)) else 0.65)

func complete() -> void:
    if not active or closing:
        return
    closing = true
    var remaining := maxf(0.0, float(earliest_reveal - Time.get_ticks_msec()) / 1000.0)
    if remaining > 0.0:
        await get_tree().create_timer(remaining).timeout
    if not is_inside_tree():
        return
    if fade != null and fade.is_running():
        fade.kill()
    fade = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    fade.tween_property(self, "modulate:a", 0.0, 0.15 if bool(Controls.pref(self, "reduced_menu_motion", false)) else 0.65)
    fade.tween_callback(_finish)

func _finish() -> void:
    active = false
    closing = false
    hide()
    set_process_input(false)
    finished.emit()

func _input(_event: InputEvent) -> void:
    if active:
        get_viewport().set_input_as_handled()
