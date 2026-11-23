extends PanelContainer
## In-game attribution sourced from ASSET_CREDITS.md and the pinned
## Sketchfab model catalog. URLs open only when explicitly clicked.
signal back_pressed
const Loc = preload("res://gameplay/localization.gd")
const MenuStyle = preload("res://ui/menu_style.gd")
const LuminousButton = preload("res://ui/luminous_button.gd")

var title_label: Label
var back_button: Button


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    custom_minimum_size = Vector2(760, 570)
    add_theme_stylebox_override("panel", MenuStyle.panel())
    var pad := MarginContainer.new()
    pad.add_theme_constant_override("margin_left", 34)
    pad.add_theme_constant_override("margin_right", 34)
    pad.add_theme_constant_override("margin_top", 28)
    pad.add_theme_constant_override("margin_bottom", 25)
    add_child(pad)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 15)
    pad.add_child(column)

    var eyebrow := Label.new()
    eyebrow.text = "CASINO ANOMALY  /  PEOPLE & SOURCES"
    eyebrow.add_theme_color_override("font_color", Color("#a5bac2"))
    eyebrow.add_theme_font_size_override("font_size", 12)
    column.add_child(eyebrow)

    title_label = Label.new()
    title_label.add_theme_color_override("font_color", MenuStyle.GOLD)
    title_label.add_theme_font_size_override("font_size", 32)
    column.add_child(title_label)

    var rule := ColorRect.new()
    rule.color = Color("#936f6e")
    rule.custom_minimum_size.y = 2
    column.add_child(rule)

    var credits := RichTextLabel.new()
    credits.bbcode_enabled = true
    credits.scroll_active = true
    credits.size_flags_vertical = Control.SIZE_EXPAND_FILL
    credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    credits.add_theme_color_override("default_color", Color("#e7e2df"))
    credits.add_theme_color_override("font_shadow_color", Color("#000000"))
    credits.add_theme_font_size_override("normal_font_size", 15)
    credits.add_theme_font_size_override("bold_font_size", 17)
    credits.add_theme_color_override("font_selected_color", Color.WHITE)
    credits.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
    credits.text = _credit_text()
    credits.meta_clicked.connect(_open_reference)
    column.add_child(credits)

    var bottom := HBoxContainer.new()
    column.add_child(bottom)
    var note := Label.new()
    note.text = "CC0  /  CC BY 4.0  /  CC BY-SA 4.0"
    note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    note.add_theme_color_override("font_color", Color("#96a3af"))
    bottom.add_child(note)

    back_button = LuminousButton.new()
    (back_button as LuminousButton).symbol = "back"
    back_button.custom_minimum_size = Vector2(156, 46)
    back_button.pressed.connect(func() -> void: back_pressed.emit())
    bottom.add_child(back_button)
    refresh_language()


func refresh_language() -> void:
    if title_label == null:
        return
    title_label.text = Loc.t("credits.title", self)
    back_button.text = Loc.t("settings.back", self)


func _open_reference(meta: Variant) -> void:
    var address := str(meta)
    if address.begins_with("https://"):
        OS.shell_open(address)


func _credit_text() -> String:
    return """[color=#e6bb81][b]CASINO ANOMALY[/b][/color]
An independent Godot game project by TeKatz.
Engine: Godot 4.5  ·  [url=https://godotengine.org/license/]MIT License[/url]

[color=#e6bb81][b]MUSIC & AMBIENCE[/b][/color]
Menu music: "hmm" — Xythe, [url=https://freesound.org/people/Xythe/sounds/115831/]Freesound #115831[/url], CC0 1.0.
Room tone: "Room Tone In An Apartment Living Room 2" — leonelmail, [url=https://freesound.org/people/leonelmail/sounds/329533/]Freesound #329533[/url], CC0 1.0. Edited into a seamless loop for the game.

[color=#e6bb81][b]3D MODELS — SKETCHFAB / CC BY 4.0[/b][/color]
Roulette Table — [url=https://sketchfab.com/3d-models/roulette-table-18a27b0e326644a0b47887d07e0d0f99]Robilben[/url]
Retro Slot Machine — [url=https://sketchfab.com/3d-models/retro-slot-machine-46f0ae338d984364ac1249451067c1a3]ARTEL_3D[/url]
Poker set — [url=https://sketchfab.com/3d-models/poker-set-841e271f392b4b3187b19fbdbb81ef62]Matth_mat[/url]
Blackjack Table — [url=https://sketchfab.com/3d-models/blackjack-table-baf7e3cbd14140ca81ea1a79d28fb635]Ravi Jangid[/url]
Business Man (Croupier) — [url=https://sketchfab.com/3d-models/business-man-low-polygon-game-character-b6f6740f883b4749abac47af0045a9dd]manoeldarochadeoliveira[/url]
Assets have been adapted for this game. License: [url=https://creativecommons.org/licenses/by/4.0/]Creative Commons Attribution 4.0[/url].

[color=#e6bb81][b]TUTORIAL MODELS — SKETCHFAB / CC BY 4.0[/b][/color]
Wall Light — [url=https://sketchfab.com/3d-models/wall-light-c723fa0a1ac3478790192acdb39161b0]Lucas Garnier[/url]
Vintage Gramophone — [url=https://sketchfab.com/3d-models/vintage-gramophone-a7508a4233a344008029d21a2f0024bd]Maxim Mavrichev[/url]
Desk Bell — [url=https://sketchfab.com/3d-models/desk-bell-cc21b304c4bb4750bdde7a8fb538b116]ClintonAbbott.Art[/url]
Original geometry fitted to the tutorial. License: [url=https://creativecommons.org/licenses/by/4.0/]CC BY 4.0[/url].

[color=#e6bb81][b]TUTORIAL RECEPTION — CC BY-SA 4.0[/b][/color]
Books with magnifier — [url=https://sketchfab.com/3d-models/books-with-magnifier-cc153ce6258b4e538d9fc7da5b5d0fe4]shuvalov.di[/url]
Licensed under [url=https://creativecommons.org/licenses/by-sa/4.0/]Creative Commons Attribution-ShareAlike 4.0[/url].
Original model and textures retained; scaled and placed in the game.

[color=#e6bb81][b]MODELS & TEXTURES — CC0[/b][/color]
[url=https://polyhaven.com/]Poly Haven[/url] — architecture materials, chandeliers, furniture, props and decor.
[url=https://ambientcg.com/view?id=Fabric037]ambientCG[/url] — Fabric037.
Poly Haven texture contributors include Dimitrios Savva and Rob Tuytel.
All relevant original sources are listed in ASSET_CREDITS.md.

[color=#e6bb81][b]SPECIAL THANKS[/b][/color]
The Godot community and creators of freely usable game assets.

[color=#9aabb8]Full attribution, source links and license details:
ASSET_CREDITS.md in the project distribution.[/color]"""
