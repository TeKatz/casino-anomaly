extends RefCounted
## Keep the logical size used by native controls and nine-slice margins,
## but upload a texture with four times as many pixels on each axis.
## Callers cache the result; no viewport-sized surfaces or per-frame rebuilds.
const DENSITY := 4


static func from_svg(svg: String, logical_size: Vector2i, source_scale: float = 1.0) -> ImageTexture:
    var image := Image.new()
    var error := image.load_svg_from_buffer(svg.to_utf8_buffer(), source_scale * float(DENSITY))
    if error != OK:
        return null
    return from_image(image, logical_size)


static func from_image(image: Image, logical_size: Vector2i) -> ImageTexture:
    var texture := ImageTexture.create_from_image(image)
    texture.set_size_override(logical_size)
    return texture
