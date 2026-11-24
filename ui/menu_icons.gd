extends RefCounted
## Nieobie Game Icon Pack v1.4 (CC0). Original SVG geometry, white tint.
## Rasterized once, cached and independent of texture import order.
const Primary = preload("res://ui/nieobie/primary.gd")
const Secondary = preload("res://ui/nieobie/secondary.gd")
static var _cache: Dictionary = {}


static func texture(name: String) -> Texture2D:
    if _cache.has(name):
        return _cache[name] as Texture2D
    var svg: String = Primary.DRAWINGS.get(name, Secondary.DRAWINGS.get(name, ""))
    if svg.is_empty():
        return null
    var image := Image.new()
    var err := image.load_svg_from_buffer(svg.to_utf8_buffer(), 1.25)
    if err != OK:
        push_warning("Cannot render menu icon: " + name)
        return null
    var result := ImageTexture.create_from_image(image)
    _cache[name] = result
    return result
