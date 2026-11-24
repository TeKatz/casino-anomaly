extends RefCounted
## Nieobie Game Icon Pack v1.4 (CC0). Original SVG geometry, white tint.
## Rasterized once, cached and independent of texture import order.
const Primary = preload("res://ui/nieobie/primary.gd")
const Secondary = preload("res://ui/nieobie/secondary.gd")
const HiDPI = preload("res://ui/hidpi_texture.gd")
static var _cache: Dictionary = {}


static func texture(name: String) -> Texture2D:
    if _cache.has(name):
        return _cache[name] as Texture2D
    var svg: String = Primary.DRAWINGS.get(name, Secondary.DRAWINGS.get(name, ""))
    if svg.is_empty():
        return null
    # Preserve the original 30px button icon layout (24px SVG × 1.25).
    var result := HiDPI.from_svg(svg, Vector2i(30, 30), 1.25)
    if result == null:
        push_warning("Cannot render menu icon: " + name)
        return null
    _cache[name] = result
    return result
