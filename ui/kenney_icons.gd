extends RefCounted
## Kenney UI Pack 2.0 (CC0), recolored for Casino Anomaly.
## Embedded vector sources: safe during first editor import and in exports.
## The editable SVG originals remain in ui/kenney/.
static var _cache: Dictionary = {}

const DRAWINGS := {
    "arrow": """<svg width="16" height="16" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path fill="#c9a45c" d="M23.6 5.15 L15.15 22.05 Q14.6 23.25 13.3 23.8 12 24.25 10.75 23.8 9.45 23.25 8.8 22.05 L0.4 5.15 Q-0.15 4.05 0.1 2.8 0.35 1.6 1.35 0.8 2.4 0 3.55 0 L20.4 0 Q21.65 0 22.65 0.8 23.7 1.6 23.85 2.8 24.2 4.05 23.6 5.15"/></svg>""",
    "check_on": """<svg width="26" height="26" viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg"><path fill="#a38b61" d="M6 0 L26 0 Q32 0 32 6 L32 26 Q32 32 26 32 L6 32 Q0 32 0 26 L0 6 Q0 0 6 0"/><path fill="#c9a45c" d="M28 6 L28 26 Q28 28 26 28 L6 28 Q4 28 4 26 L4 6 Q4 4 6 4 L26 4 Q28 4 28 6"/><path fill="#15171b" d="M8.45 17.5 Q7.95 16.85 8.05 16.05 8.1 15.2 8.75 14.7 9.4 14.2 10.25 14.3 11.05 14.35 11.55 15 L13.85 17.85 20.45 9.75 Q21 9.1 21.8 9 22.6 8.9 23.25 9.45 23.9 10 24 10.8 24.1 11.6 23.55 12.25 L15.4 22.25 Q15 22.75 14.45 22.95 L13.3 22.95 Q12.7 22.95 12.3 22.25 L8.45 17.5"/></svg>""",
    "check_off": """<svg width="26" height="26" viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg"><path fill="#a38b61" d="M6 0 L26 0 Q32 0 32 6 L32 26 Q32 32 26 32 L6 32 Q0 32 0 26 L0 6 Q0 0 6 0"/><path fill="#202228" d="M28 6 L28 26 Q28 28 26 28 L6 28 Q4 28 4 26 L4 6 Q4 4 6 4 L26 4 Q28 4 28 6"/></svg>""",
    "check_on_disabled": """<svg width="26" height="26" viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg"><path fill="#53545a" d="M6 0 L26 0 Q32 0 32 6 L32 26 Q32 32 26 32 L6 32 Q0 32 0 26 L0 6 Q0 0 6 0"/><path fill="#77777b" d="M28 6 L28 26 Q28 28 26 28 L6 28 Q4 28 4 26 L4 6 Q4 4 6 4 L26 4 Q28 4 28 6"/><path fill="#15171b" d="M8.45 17.5 Q7.95 16.85 8.05 16.05 8.1 15.2 8.75 14.7 9.4 14.2 10.25 14.3 11.05 14.35 11.55 15 L13.85 17.85 20.45 9.75 Q21 9.1 21.8 9 22.6 8.9 23.25 9.45 23.9 10 24 10.8 24.1 11.6 23.55 12.25 L15.4 22.25 Q15 22.75 14.45 22.95 L13.3 22.95 Q12.7 22.95 12.3 22.25 L8.45 17.5"/></svg>""",
    "check_off_disabled": """<svg width="26" height="26" viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg"><path fill="#53545a" d="M6 0 L26 0 Q32 0 32 6 L32 26 Q32 32 26 32 L6 32 Q0 32 0 26 L0 6 Q0 0 6 0"/><path fill="#202228" d="M28 6 L28 26 Q28 28 26 28 L6 28 Q4 28 4 26 L4 6 Q4 4 6 4 L26 4 Q28 4 28 6"/></svg>""",
    "slider": """<svg width="18" height="24" viewBox="0 0 24 32" xmlns="http://www.w3.org/2000/svg"><path fill="#e0c38a" d="M1.15 9.15 L9.15 1.15 Q10.35 0 12 0 Q13.65 0 14.85 1.15 L22.85 9.15 Q24 10.35 24 12 L24 28 Q24 29.65 22.85 30.85 Q21.9 32 20 32 L4 32 Q2.1 32 1.15 30.85 Q0 29.65 0 28 L0 12 Q0 10.35 1.15 9.15"/><path fill="#a38149" d="M4.25 11.8 L4 12.05 4 28 20 28 20 12.05 19.75 11.75 12.05 4.05 11.8 4.25 4.25 11.8"/></svg>""",
    "slider_hover": """<svg width="18" height="24" viewBox="0 0 24 32" xmlns="http://www.w3.org/2000/svg"><path fill="#e0c38a" d="M1.15 9.15 L9.15 1.15 Q10.35 0 12 0 Q13.65 0 14.85 1.15 L22.85 9.15 Q24 10.35 24 12 L24 28 Q24 29.65 22.85 30.85 Q21.9 32 20 32 L4 32 Q2.1 32 1.15 30.85 Q0 29.65 0 28 L0 12 Q0 10.35 1.15 9.15"/><path fill="#f0d9a0" d="M4.25 11.8 L4 12.05 4 28 20 28 20 12.05 19.75 11.75 12.05 4.05 11.8 4.25 4.25 11.8"/></svg>""",
    "slider_disabled": """<svg width="18" height="24" viewBox="0 0 24 32" xmlns="http://www.w3.org/2000/svg"><path fill="#737477" d="M1.15 9.15 L9.15 1.15 Q10.35 0 12 0 Q13.65 0 14.85 1.15 L22.85 9.15 Q24 10.35 24 12 L24 28 Q24 29.65 22.85 30.85 Q21.9 32 20 32 L4 32 Q2.1 32 1.15 30.85 Q0 29.65 0 28 L0 12 Q0 10.35 1.15 9.15"/><path fill="#4c4d51" d="M4.25 11.8 L4 12.05 4 28 20 28 20 12.05 19.75 11.75 12.05 4.05 11.8 4.25 4.25 11.8"/></svg>"""
}


static func texture(name: String) -> Texture2D:
    if _cache.has(name):
        return _cache[name] as Texture2D
    if not DRAWINGS.has(name):
        return null
    var image := Image.new()
    var svg: String = DRAWINGS[name]
    var err := image.load_svg_from_buffer(svg.to_utf8_buffer())
    if err != OK:
        push_warning("Cannot render Kenney UI icon: " + name)
        return null
    var result := ImageTexture.create_from_image(image)
    _cache[name] = result
    return result
