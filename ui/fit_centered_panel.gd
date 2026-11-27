extends Control
## Center a panel at its natural size; scale down only when the logical
## viewport is too small. Full-screen overlay cannot expand to child minimum.
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(is_visible_in_tree())
    visibility_changed.connect(_visibility)

func _visibility() -> void:
    set_process(is_visible_in_tree())
    _layout()

func _process(_delta: float) -> void:
    _layout()

func _layout() -> void:
    for item in get_children():
        if not item is Control or not item.visible:
            continue
        var panel := item as Control
        var natural := panel.get_combined_minimum_size()
        if natural.x <= 0.0 or natural.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
            continue
        var factor := minf(1.0, minf(maxf(1.0, size.x - 20.0) / natural.x, maxf(1.0, size.y - 20.0) / natural.y))
        panel.size = natural
        panel.pivot_offset = Vector2.ZERO
        panel.scale = Vector2.ONE * factor
        # Align the static panel origin to the output pixel grid instead
        # of introducing a half-pixel offset while centering it.
        var centered := (size - natural * factor) * 0.5
        var transform := get_global_transform_with_canvas()
        var output := get_viewport().get_final_transform()
        var to_pixels := output * transform
        if absf(to_pixels.determinant()) > 0.00001:
            centered = to_pixels.affine_inverse() * (to_pixels * centered).round()
        panel.position = centered
