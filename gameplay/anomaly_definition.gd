extends Resource
## Add a .tres of this type under res://gameplay/anomaly_definitions/.
## ResourceLoader discovers it in editor and exported builds without a code edit.
@export var id := ""
@export var category_en := ""
@export var category_de := ""
@export var title_en := ""
@export var title_de := ""
@export_multiline var description_en := ""
@export_multiline var description_de := ""
@export var handler: Script
@export var target_path := ""
@export var replacement_text := ""
@export var enabled := true
@export var discoverable := true

@export var has_position_offset := false
@export var position_offset := Vector3.ZERO
@export var has_rotation_degrees := false
@export var rotation_degrees := Vector3.ZERO
@export var has_color := false
@export var color := Color.WHITE
@export var has_energy_scale := false
@export var energy_scale := 1.0
@export var has_visible := false
@export var visible := true


func to_entry() -> Dictionary:
    var entry := {
        "id": id,
        "category_en": category_en, "category_de": category_de,
        "title_en": title_en, "title_de": title_de,
        "description_en": description_en, "description_de": description_de,
        "handler": handler, "target_path": target_path,
        "discoverable": discoverable
    }
    if not replacement_text.is_empty():
        entry["replacement_text"] = replacement_text
    if has_position_offset:
        entry["position_offset"] = position_offset
    if has_rotation_degrees:
        entry["rotation_degrees"] = rotation_degrees
    if has_color:
        entry["color"] = color
    if has_energy_scale:
        entry["energy_scale"] = energy_scale
    if has_visible:
        entry["visible"] = visible
    return entry
