extends RefCounted
## Explicit scene registry: future rooms get their own bake script and output.
## Do not infer a target from the currently selected node.

const CASINO_SCENE := "res://gameplay/casino/main.tscn"
const BACKROOMS_SCENE := "res://backrooms/backrooms_labyrinth.tscn"
const BACKROOMS_OUTPUT := "res://backrooms/backrooms_voxel_gi.res"

static func for_scene(scene_path: String) -> Dictionary:
    match scene_path:
        CASINO_SCENE:
            return {
                "label": "Casino (beide Flügel)",
                "script": "res://tools/bake_voxel_gi.gd",
                "output": "res://lighting/main_wing.res und res://lighting/west_wing.res",
            }
        BACKROOMS_SCENE:
            return {
                "label": "Backrooms-Labyrinth",
                "script": "res://tools/bake_backrooms_voxel_gi.gd",
                "output": BACKROOMS_OUTPUT,
            }
        _:
            return {}

static func process_args(scene_path: String, project_path: String) -> PackedStringArray:
    var target := for_scene(scene_path)
    if target.is_empty():
        return PackedStringArray()
    return PackedStringArray(["--path", project_path, "--rendering-method", "forward_plus",
        "--script", str(target["script"])])
