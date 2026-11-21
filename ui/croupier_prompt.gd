@tool
extends Node3D
## Crisp, single-sprite interaction plaque above the NPC. A tiny SubViewport
## renders one static Control composition; only the 3D sprite moves in-game.
## Unlike the old Label3D, this has a real keycap, satin background and border.
const VIEW_SIZE := Vector2i(448, 112)
const BOB_AMPLITUDE := 0.025
const BOB_SPEED := 1.8

var prompt_text := "E · Talk"
var caption: Label
var plaque: Sprite3D
var viewport: SubViewport
var _origin := Vector3.ZERO
var _clock := 0.0
var _shown := false
var _fade: Tween


func _ready() -> void:
    _origin = position
    _make_plaque()
    _apply_caption()
    if Engine.is_editor_hint():
        visible = true
        plaque.modulate.a = 1.0
    else:
        visible = false
        plaque.modulate.a = 0.0


func _make_plaque() -> void:
    viewport = SubViewport.new()
    viewport.name = "PlaqueViewport"
    viewport.size = VIEW_SIZE
    viewport.disable_3d = true
    viewport.transparent_bg = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
    add_child(viewport)

    var root := Control.new()
    root.name = "PlaqueRoot"
    root.size = Vector2(VIEW_SIZE)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    viewport.add_child(root)

    var card := PanelContainer.new()
    card.name = "Card"
    card.position = Vector2(15, 14)
    card.size = Vector2(418, 80)
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var shell := StyleBoxFlat.new()
    shell.bg_color = Color("#111d2e", 0.96)
    shell.border_color = Color("#d8ba83")
    shell.set_border_width_all(2)
    shell.set_corner_radius_all(16)
    shell.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
    shell.shadow_size = 10
    card.add_theme_stylebox_override("panel", shell)
    root.add_child(card)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 22)
    margin.add_theme_constant_override("margin_right", 25)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_bottom", 12)
    margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.add_child(margin)

    var layout := HBoxContainer.new()
    layout.add_theme_constant_override("separation", 17)
    layout.alignment = BoxContainer.ALIGNMENT_CENTER
    layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
    margin.add_child(layout)

    var keycap := PanelContainer.new()
    keycap.name = "Keycap"
    keycap.custom_minimum_size = Vector2(55, 53)
    keycap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var keyface := StyleBoxFlat.new()
    keyface.bg_color = Color("#374758")
    keyface.border_color = Color("#c5d1d9")
    keyface.set_border_width_all(1)
    keyface.border_width_bottom = 3
    keyface.set_corner_radius_all(10)
    keyface.shadow_color = Color(0, 0, 0, 0.42)
    keyface.shadow_size = 3
    keycap.add_theme_stylebox_override("panel", keyface)
    layout.add_child(keycap)

    var key := Label.new()
    key.text = "E"
    key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    key.add_theme_font_size_override("font_size", 28)
    key.add_theme_color_override("font_color", Color("#f2f2e8"))
    keycap.add_child(key)

    caption = Label.new()
    caption.name = "ActionCaption"
    caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    caption.add_theme_font_size_override("font_size", 26)
    caption.add_theme_color_override("font_color", Color("#f4e5c8"))
    layout.add_child(caption)

    plaque = Sprite3D.new()
    plaque.name = "PromptSprite"
    plaque.texture = viewport.get_texture()
    plaque.pixel_size = 0.00225
    plaque.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    plaque.shaded = false
    add_child(plaque)


func set_prompt_text(value: String) -> void:
    prompt_text = value
    _apply_caption()


func _apply_caption() -> void:
    if caption == null:
        return
    var pieces := prompt_text.split("·", false, 1)
    caption.text = pieces[1].strip_edges() if pieces.size() > 1 else prompt_text
    if viewport != null:
        viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func set_prompt_visible(enabled: bool) -> void:
    if Engine.is_editor_hint() or _shown == enabled:
        return
    _shown = enabled
    if _fade != null and _fade.is_running():
        _fade.kill()
    if enabled:
        visible = true
    _fade = create_tween()
    _fade.tween_property(plaque, "modulate:a", 1.0 if enabled else 0.0, 0.22) \
            .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    if not enabled:
        _fade.tween_callback(func() -> void:
            if not _shown:
                visible = false
        )


func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        return
    if not _shown:
        position = _origin
        return
    _clock += delta
    position = _origin + Vector3(0.0, sin(_clock * BOB_SPEED) * BOB_AMPLITUDE, 0.0)
