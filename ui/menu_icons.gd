extends RefCounted
## Lightweight original line icons. Rasterized once from SVG to crisp 36px
## ImageTextures and reused across the entire exported game, without fonts.
static var _cache: Dictionary = {}

const DRAWINGS := {
    "play": "<path d='M8 5l11 7-11 7z'/>",
    "resume": "<path d='M7 4v16l12-8z'/>",
    "settings": "<path d='M10 3h4l.6 2.2 2 .9 2-.9 2.8 2.8-.9 2 .9 2L23 12v0l-2.4.9-.9 2 .9 2-2.8 2.8-2-.9-2 .9L14 22h-4l-.6-2.2-2-.9-2 .9-2.8-2.8.9-2-.9-2L1 12l2.4-.9.9-2-.9-2 2.8-2.8 2 .9 2-.9z' transform='translate(1 0) scale(.92)'/><circle cx='12' cy='12' r='3'/>",
    "archive": "<path d='M4 5a2 2 0 0 1 2-2h14v16H6a2 2 0 0 0-2 2z'/><path d='M4 5v16a2 2 0 0 0 2 2h14'/><path d='M9 8h7M9 12h7'/>",
    "stats": "<path d='M3 20h18M6 17v-6M11 17V6M16 17v-9M21 17v-4'/>",
    "credits": "<path d='M12 2l3.2 6.6 7.3 1-5.3 5.2 1.3 7.2L12 18.6 5.5 22l1.3-7.2-5.3-5.2 7.3-1z'/>",
    "new": "<path d='M12 3v18M3 12h18'/><circle cx='12' cy='12' r='9'/>",
    "load": "<path d='M3 7V5a2 2 0 0 1 2-2h5l2 3h7a2 2 0 0 1 2 2v2'/><path d='M3 10h18v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z'/><path d='M12 11v7m-3-3 3 3 3-3'/>",
    "home": "<path d='M3 10l9-7 9 7v11h-7v-7h-4v7H3z'/>",
    "quit": "<path d='M12 2v10'/><path d='M7 5a9 9 0 1 0 10 0'/>",
    "update": "<path d='M20 7v5h-5M4 17v-5h5'/><path d='M5 9a8 8 0 0 1 14-2l1 5M4 12l1 5a8 8 0 0 0 14-2'/>",
    "install": "<path d='M12 3v13m-5-5 5 5 5-5'/><path d='M4 18v3h16v-3'/>",
    "profile": "<circle cx='12' cy='8' r='4'/><path d='M4 21v-2a8 8 0 0 1 16 0v2z'/>",
    "add_profile": "<circle cx='10' cy='7' r='4'/><path d='M2 21v-2a8 8 0 0 1 14-5M18 15v7m-3.5-3.5h7'/>",
    "edit": "<path d='M4 20l4.5-1 11-11-3.5-3.5-11 11zM13.5 7l3.5 3.5'/><path d='M4 20h16'/>",
    "delete": "<path d='M4 7h16M9 4h6M6 7l1 14h10l1-14M10 11v6M14 11v6'/>",
    "back": "<path d='M20 12H4m7-7-7 7 7 7'/>",
    "history": "<path d='M4 5v5h5M4.5 10a8 8 0 1 1 1.5 7'/><path d='M12 7v5l4 2'/>",
    "info": "<circle cx='12' cy='12' r='9'/><path d='M12 11v6M12 7h.01'/>",
    "save": "<path d='M4 3h13l3 3v15H4z'/><path d='M8 3v7h9V3M8 21v-7h8v7'/>"
}


static func texture(name: String) -> Texture2D:
    if name.is_empty() or not DRAWINGS.has(name):
        return null
    if _cache.has(name):
        return _cache[name] as Texture2D
    var svg := ("<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' " +
        "viewBox='0 0 24 24' fill='none' stroke='white' stroke-width='1.75' " +
        "stroke-linecap='round' stroke-linejoin='round'>" +
        str(DRAWINGS[name]) + "</svg>")
    var image := Image.new()
    var err := image.load_svg_from_buffer(svg.to_utf8_buffer(), 1.25)
    if err != OK:
        push_warning("Cannot render menu icon: " + name)
        return null
    var result := ImageTexture.create_from_image(image)
    _cache[name] = result
    return result
