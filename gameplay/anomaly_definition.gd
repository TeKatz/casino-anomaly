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
@export var preserve_label_color := false
@export var enabled := true
@export var discoverable := true
@export_enum("common", "uncommon", "rare", "exceptional", "singularity") var rarity := "common"
@export_range(1, 5) var difficulty := 2
@export var family_id := ""
@export var variant_name_en := ""
@export var variant_name_de := ""

@export var has_position_offset := false
@export var position_offset := Vector3.ZERO
@export var has_rotation_degrees := false
@export var rotation_degrees := Vector3.ZERO
@export var has_color := false
@export var color := Color.WHITE
@export var has_energy_scale := false
@export var energy_scale := 1.0
# Optional original light whose authored energy defines this effect strength.
@export var energy_reference_path := ""
@export var has_visible := false
@export var visible := true


func to_entry() -> Dictionary:
    var entry := {
        "id": id,
        "category_en": category_en, "category_de": category_de,
        "title_en": title_en, "title_de": title_de,
        "description_en": description_en, "description_de": description_de,
        "handler": handler, "target_path": target_path,
        "discoverable": discoverable, "rarity": rarity, "difficulty": difficulty,
        "family_id": family_id if not family_id.is_empty() else id,
        "variant_name_en": variant_name_en, "variant_name_de": variant_name_de
    }
    if not replacement_text.is_empty():
        entry["replacement_text"] = replacement_text
    if preserve_label_color:
        entry["preserve_label_color"] = true
    if has_position_offset:
        entry["position_offset"] = position_offset
    if has_rotation_degrees:
        entry["rotation_degrees"] = rotation_degrees
    if has_color:
        entry["color"] = color
    if has_energy_scale:
        entry["energy_scale"] = energy_scale
    if not energy_reference_path.is_empty():
        entry["energy_reference_path"] = energy_reference_path
    if has_visible:
        entry["visible"] = visible
    return entry
