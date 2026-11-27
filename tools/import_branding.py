"""Install the approved Phase 6 artwork without changing its bytes.

Run from the repository with the original approved ZIP:
    python tools/import_branding.py PATH_TO_ZIP --commit
The --commit option requires a clean dev checkout; it does not push.
No network access or third-party Python packages are needed.
"""
from __future__ import annotations

import argparse
import hashlib
import re
import struct
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = {
    "casino_anomaly_logo.png": ("e0aa8eef3cfbf391dc0afb3b8977b8653334fdb31ca18dbbde0a591179dfe648", (1739, 856)),
    "casino_anomaly_emblem.png": ("f4e25efae8db05d2c7a7aa094a452568bd2ee39cfb844452d2fc7607abcf3556", (628, 632)),
    "casino_anomaly_wordmark.png": ("5705f3ab240e87893ee90f422923747c657141630a8fd042c49fab706c894878", (1723, 197)),
    "casino_anomaly_icon.png": ("f420a7aadb3cdd6ce1a03aa75891ed98b7c31c7e2dfa97e3ae60db449130d700", (512, 512)),
    "casino_anomaly.ico": ("b4fb898f21964892b26d65a6570543e1ecab6a4ee05f32bab57e50a83d74d993", None),
    "casino_anomaly_cinematic_1920x1080.png": ("2aef1c6faa43adc071c160a1950c1a3a5a91fbc2b443107256ffbf153e1d26b3", (1920, 1080)),
}
OLD = "branding/casino_anomaly.svg"
LEGACY = (OLD, OLD + ".import")
ICO_SIZES = {16, 24, 32, 48, 64, 128, 256}
BRAND = "res://branding/"
SOURCE_FILES = (
    "menu.tscn", "ui/menu_startup_intro.tscn", "gameplay/scene_loader.gd",
    "project.godot", "export_presets.cfg", ".gitattributes",
    "src/CasinoAnomaly.Updater/CasinoAnomaly.Updater.csproj",
    "src/CasinoAnomaly.Updater/Program.cs", "README.md",
    ".github/workflows/development-release.yml",
    "tests/menu_visual_qa.gd", "tests/loading_transition_qa.gd",
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def validate_asset(name: str, data: bytes) -> None:
    expected, dimensions = ASSETS[name]
    if sha(data) != expected:
        raise ValueError(f"{name}: not the approved byte-for-byte asset")
    if dimensions is not None:
        if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
            raise ValueError(f"{name}: invalid PNG")
        if struct.unpack_from(">II", data, 16) != dimensions:
            raise ValueError(f"{name}: incorrect PNG dimensions")
        # RGBA is required on the four freestanding graphics.
        if "cinematic" not in name and data[25] != 6:
            raise ValueError(f"{name}: alpha channel is missing")
    else:
        reserved, kind, count = struct.unpack_from("<HHH", data)
        if reserved or kind != 1 or count != 7:
            raise ValueError("Invalid multi-resolution ICO")
        sizes = set()
        for i in range(count):
            w, h, _, _, _, _, length, offset = struct.unpack_from("<BBBBHHII", data, 6 + 16 * i)
            w, h = w or 256, h or 256
            if w != h or length == 0 or offset + length > len(data):
                raise ValueError("Invalid ICO image directory")
            sizes.add(w)
        if sizes != ICO_SIZES:
            raise ValueError("Required ICO resolutions are missing")


def read_package(path: Path) -> dict[str, bytes]:
    result = {}
    with zipfile.ZipFile(path) as archive:
        for name in ASSETS:
            matches = [i for i in archive.infolist() if not i.is_dir() and i.filename == name]
            if len(matches) != 1:
                raise ValueError(f"Expected exactly one root entry: {name}")
            data = archive.read(matches[0])
            validate_asset(name, data)
            result[name] = data
    return result


def once(text: str, old: str, new: str) -> str:
    if text.count(old) != 1:
        raise ValueError(f"Unexpected source context: {old[:120]}")
    return text.replace(old, new, 1)


def png_import(template: str, name: str) -> str:
    # Preserve the existing lossless import policy; enable mipmaps for
    # downscaled raster artwork. Godot assigns a fresh UID on import.
    path = BRAND + name
    dest = "res://.godot/imported/" + name + "-" + hashlib.md5(path.encode()).hexdigest() + ".ctex"
    result = re.sub(r'^uid=.*\n', '', template, flags=re.M)
    result = re.sub(r'^path=.*$', f'path="{dest}"', result, flags=re.M)
    result = re.sub(r'^source_file=.*$', f'source_file="{path}"', result, flags=re.M)
    result = re.sub(r'^dest_files=.*$', f'dest_files=["{dest}"]', result, flags=re.M)
    result = once(result, "mipmaps/generate=false", "mipmaps/generate=true")
    result = once(result, "detect_3d/compress_to=1", "detect_3d/compress_to=0")
    result = re.sub(r'^(svg/|editor/).*?\n', '', result, flags=re.M)
    return result


def plan(root: Path) -> dict[str, str]:
    source = {p: (root / p).read_text(encoding="utf-8") for p in SOURCE_FILES}
    out = dict(source)
    # The existing Brand parent, its layout rule, animation and compact
    # behavior remain unchanged. Only its title artwork and nearby spacing
    # change; menu buttons and the panorama are byte-for-byte preserved.
    p = "menu.tscn"
    s = source[p]
    s = once(s, "[gd_scene load_steps=7 format=3]", "[gd_scene load_steps=8 format=3]")
    s = once(s, '[ext_resource type="PackedScene" path="res://ui/menu_startup_intro.tscn" id="5_intro"]',
             '[ext_resource type="PackedScene" path="res://ui/menu_startup_intro.tscn" id="5_intro"]\n'
             '[ext_resource type="Texture2D" path="res://branding/casino_anomaly_logo.png" id="6_brand"]')
    start = s.index('[node name="Casino" type="Label" parent="Brand"]')
    end = s.index('[node name="Rule" type="ColorRect" parent="Brand"]', start)
    s = s[:start] + '''[node name="Logo" type="TextureRect" parent="Brand"]
layout_mode = 0
offset_top = 31.0
offset_right = 410.0
offset_bottom = 233.0
mouse_filter = 2
texture_filter = 4
texture = ExtResource("6_brand")
expand_mode = 1
stretch_mode = 5

''' + s[end:]
    s = once(s, "offset_top = 181.0\noffset_right = 92.0\noffset_bottom = 183.0",
             "offset_top = 243.0\noffset_right = 92.0\noffset_bottom = 245.0")
    s = once(s, "offset_top = 199.0\noffset_right = 530.0\noffset_bottom = 230.0",
             "offset_top = 261.0\noffset_right = 530.0\noffset_bottom = 292.0")
    out[p] = s

    # Intro: emblem plus exact approved wordmark in the existing VBox.
    # Retain the Creator node, fade timings, cover and input handling.
    p = "ui/menu_startup_intro.tscn"
    s = once(source[p], "[gd_scene load_steps=3 format=3]", "[gd_scene load_steps=4 format=3]")
    s = once(s, '[ext_resource type="Texture2D" path="res://branding/casino_anomaly.svg" id="2"]',
             '[ext_resource type="Texture2D" path="res://branding/casino_anomaly_emblem.png" id="2"]\n'
             '[ext_resource type="Texture2D" path="res://branding/casino_anomaly_wordmark.png" id="3_wordmark"]')
    s = once(s, 'texture = ExtResource("2")', 'texture_filter = 4\ntexture = ExtResource("2")')
    start = s.index('[node name="Title" type="Label" parent="Center/Content"]')
    end = s.index('[node name="Rule" type="ColorRect" parent="Center/Content"]', start)
    s = s[:start] + '''[node name="Title" type="TextureRect" parent="Center/Content"]
custom_minimum_size = Vector2(320, 43)
layout_mode = 2
size_flags_horizontal = 4
mouse_filter = 2
texture_filter = 4
texture = ExtResource("3_wordmark")
expand_mode = 1
stretch_mode = 5

''' + s[end:]
    out[p] = s

    p = "gameplay/scene_loader.gd"
    s = once(source[p], '    mark.texture = load("res://branding/casino_anomaly.svg") as Texture2D',
             '    mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS\n'
             '    mark.texture = load("res://branding/casino_anomaly_emblem.png") as Texture2D')
    s = once(s, '''    var heading := Label.new()
    heading.text = "CASINO ANOMALY"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 30)
    heading.add_theme_color_override("font_color", Color("#f4e8df"))
    stack.add_child(heading)''', '''    var heading := TextureRect.new()
    heading.name = "BrandWordmark"
    heading.custom_minimum_size = Vector2(300, 39)
    heading.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    heading.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    heading.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    heading.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
    heading.texture = load("res://branding/casino_anomaly_wordmark.png") as Texture2D
    stack.add_child(heading)''')
    out[p] = s

    p = "project.godot"
    out[p] = once(source[p], 'config/icon="res://branding/casino_anomaly.svg"',
                  'config/icon="res://branding/casino_anomaly_icon.png"\n'
                  'config/windows_native_icon="res://branding/casino_anomaly.ico"')
    p = "export_presets.cfg"
    s = once(source[p], 'application/icon="res://branding/casino_anomaly.svg"',
             'application/icon="res://branding/casino_anomaly.ico"')
    s = once(s, 'include_filter="*.json, audio/footsteps/AUDIO_CREDITS.md, ASSET_CREDITS.md"',
             'include_filter="*.json, audio/footsteps/AUDIO_CREDITS.md, ASSET_CREDITS.md, branding/casino_anomaly.ico"')
    out[p] = once(s, 'models/backrooms/oxygen/sources/*.zip"',
                  'models/backrooms/oxygen/sources/*.zip,branding/casino_anomaly_cinematic_1920x1080.png"')
    p = ".gitattributes"
    out[p] = once(source[p], "*.png -text\n", "*.png -text\n*.ico -text\n")

    # The updater's executable and window use the same ICO, without
    # changing any update contract, layout, download or rollback logic.
    p = "src/CasinoAnomaly.Updater/CasinoAnomaly.Updater.csproj"
    out[p] = once(source[p], "    <AssemblyName>CasinoAnomaly.Updater</AssemblyName>",
                  "    <AssemblyName>CasinoAnomaly.Updater</AssemblyName>\n"
                  "    <ApplicationIcon>../../branding/casino_anomaly.ico</ApplicationIcon>")
    p = "src/CasinoAnomaly.Updater/Program.cs"
    out[p] = once(source[p], "        window.Controls.Add(status);",
                  "        using var brandIcon = System.Drawing.Icon.ExtractAssociatedIcon(Environment.ProcessPath!);\n"
                  "        if (brandIcon is not null)\n"
                  "            window.Icon = brandIcon;\n"
                  "        window.Controls.Add(status);")

    p = "README.md"
    out[p] = re.sub(
        r'^The application and Windows export preset reference .*?$', 
        'The application uses the approved Corrupted Luxury artwork in the branding directory. The supplied multi-resolution ICO is used for the Windows executable, taskbar and updater; the menu, intro and loader use the original transparent PNGs. If Explorer retains a previous icon after updating, refresh its icon cache.',
        source[p], count=1, flags=re.M)
    if out[p] == source[p]:
        raise ValueError("Unexpected README branding section")
    p = ".github/workflows/development-release.yml"
    s = once(source[p], "        run: python3 -m unittest discover -s tests -p 'test_*.py'",
             "        run: python3 -m unittest discover -s tests -p 'test_*.py'\n"
             "      - name: Verify approved branding assets\n"
             "        run: python3 tools/import_branding.py --verify")
    s = once(s, 'branding/casino_anomaly.svg))', 'branding/casino_anomaly.ico))')
    out[p] = once(s, 'application/icon="res://branding/casino_anomaly.svg"',
                  'application/icon="res://branding/casino_anomaly.ico"')

    # Add to the existing test cases, preserving all prior assertions.
    p = "tests/menu_visual_qa.gd"
    s = once(source[p], '    var intro := menu.get_node("StartupIntro") as ColorRect',
             '''    var logo := menu.get_node_or_null("Brand/Logo") as TextureRect
    if logo == null or logo.texture == null or logo.texture.resource_path != "res://branding/casino_anomaly_logo.png" or logo.texture.get_size() != Vector2(1739,856) or logo.expand_mode != TextureRect.EXPAND_IGNORE_SIZE or logo.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
        _fail("Approved main-menu logo missing or distorted")
        return
    if logo.get_global_rect().end.x >= bounds.position.x and (menu.get_node("Brand") as Control).visible:
        _fail("Brand artwork overlaps the menu panel")
        return
    var intro := menu.get_node("StartupIntro") as ColorRect
    var emblem := intro.get_node("Center/Content/Logo") as TextureRect
    var wordmark := intro.get_node("Center/Content/Title") as TextureRect
    if emblem.texture == null or emblem.texture.resource_path != "res://branding/casino_anomaly_emblem.png" or wordmark.texture == null or wordmark.texture.resource_path != "res://branding/casino_anomaly_wordmark.png" or emblem.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED or wordmark.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
        _fail("Intro must use the approved aspect-preserving emblem and wordmark")
        return''')
    out[p] = s
    p = "tests/loading_transition_qa.gd"
    out[p] = once(source[p], '''    if not ResourceLoader.exists("res://branding/casino_anomaly.svg"):
        _fail("Custom game icon is missing")
        return''', '''    if str(ProjectSettings.get_setting("application/config/icon")) != "res://branding/casino_anomaly_icon.png" or str(ProjectSettings.get_setting("application/config/windows_native_icon")) != "res://branding/casino_anomaly.ico":
        _fail("Approved application or Windows native icon missing")
        return
    var mark := loader.get("mark") as TextureRect
    var wordmark := loader.find_child("BrandWordmark",true,false) as TextureRect
    if mark == null or mark.texture == null or mark.texture.resource_path != "res://branding/casino_anomaly_emblem.png" or wordmark == null or wordmark.texture == null or wordmark.texture.resource_path != "res://branding/casino_anomaly_wordmark.png" or mark.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED or wordmark.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
        _fail("Loading screen lost the approved branding or aspect ratio")
        return''')

    template = (root / LEGACY[1]).read_text(encoding="utf-8")
    for name in ASSETS:
        if name.endswith(".png") and "cinematic" not in name:
            out["branding/" + name + ".import"] = png_import(template, name)
    for path in SOURCE_FILES:
        if out[path] == source[path] or OLD in out[path]:
            raise ValueError(f"Incomplete branding replacement: {path}")
    return out


def verify(root: Path) -> None:
    for name in ASSETS:
        validate_asset(name, (root / "branding" / name).read_bytes())
    for path in LEGACY:
        if (root / path).exists():
            raise ValueError(f"Retired asset still present: {path}")
    expected = {
        "menu.tscn": ("casino_anomaly_logo.png", 'name="Logo" type="TextureRect" parent="Brand"'),
        "ui/menu_startup_intro.tscn": ("casino_anomaly_emblem.png", "casino_anomaly_wordmark.png"),
        "gameplay/scene_loader.gd": ("casino_anomaly_emblem.png", "casino_anomaly_wordmark.png"),
        "project.godot": ('config/icon="res://branding/casino_anomaly_icon.png"',
                          'config/windows_native_icon="res://branding/casino_anomaly.ico"'),
        "export_presets.cfg": ('application/icon="res://branding/casino_anomaly.ico"', "branding/casino_anomaly_cinematic_1920x1080.png"),
        "src/CasinoAnomaly.Updater/CasinoAnomaly.Updater.csproj": ("<ApplicationIcon>../../branding/casino_anomaly.ico</ApplicationIcon>",),
    }
    for path in SOURCE_FILES:
        content = (root / path).read_text(encoding="utf-8")
        if OLD in content or not all(item in content for item in expected.get(path, ())):
            raise ValueError(f"Unfinished integration: {path}")


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


def install(root: Path, assets: dict[str, bytes]) -> list[str]:
    if not (root / OLD).exists():
        verify(root)
        return []
    edits = plan(root)
    writes = {p: s.encode("utf-8") for p, s in edits.items()}
    for name, data in assets.items():
        path = "branding/" + name
        validate_asset(name, data)
        writes[path] = data
    if set(assets) != set(ASSETS):
        raise ValueError("Incomplete set of approved assets")
    # All source-context and asset checks occur before any writes. Refuse
    # to overwrite unrelated files that may already occupy new paths.
    for path, data in writes.items():
        dest = root / path
        if path not in SOURCE_FILES and dest.exists() and dest.read_bytes() != data:
            raise ValueError(f"Existing file would be overwritten: {path}")
    backup = {p: (root / p).read_bytes() if (root / p).exists() else None
              for p in (*writes, *LEGACY)}
    try:
        for path, data in writes.items():
            dest = root / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
        for path in LEGACY:
            (root / path).unlink()
        verify(root)
        # Catch any remaining actual tracked source reference. The import
        # tool and its tests intentionally mention the retired path.
        if (root / ".git").exists():
            proc = subprocess.run(["git", "-C", str(root), "grep", "-l", "-F", OLD,
                                   "--", ":!tools/import_branding.py", ":!tests/test_branding_import.py"],
                                  text=True, capture_output=True)
            remaining = [p for p in proc.stdout.splitlines() if p not in LEGACY]
            if proc.returncode not in (0, 1) or remaining:
                raise ValueError("Unreviewed old branding reference: " + ", ".join(remaining))
    except BaseException:
        for path, data in backup.items():
            dest = root / path
            if data is None:
                dest.unlink(missing_ok=True)
            else:
                dest.write_bytes(data)
        raise
    return list(writes) + list(LEGACY)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("zip", type=Path, nargs="?")
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--commit", action="store_true")
    args = parser.parse_args()
    try:
        if args.verify:
            verify(ROOT)
            print("Approved branding SHA-256, ICO and source references verified.")
            return 0
        if args.zip is None:
            parser.error("Provide the original approved branding ZIP")
        if git(ROOT, "branch", "--show-current") != "dev":
            raise ValueError("Branding integration is scoped to the dev branch")
        if args.commit and git(ROOT, "status", "--porcelain"):
            raise ValueError("Commit or stash local changes before running --commit")
        changed = install(ROOT, read_package(args.zip))
        if args.commit and changed:
            git(ROOT, "add", "-A", "--", *changed)
            print(git(ROOT, "commit", "-m", "Integrate approved Corrupted Luxury branding"))
        print("Approved branding installed and verified. No push was performed.")
        return 0
    except (OSError, ValueError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        print(f"Branding integration aborted: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
