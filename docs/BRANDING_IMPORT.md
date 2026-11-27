# Corrupted Luxury – Phase 6 asset import

The approved ZIP is the only source of the six branding files. Do not
regenerate, resize or recompress them. Its SHA-256-pinned import tool
updates the existing menu title, intro and loading marks, project and
Windows icons, updater icon, import settings and the relevant CI tests.
It preserves the existing panorama, menu layout outside the brand area,
button skins, sound, creator text, animation and gameplay.

From a clean local dev checkout:

    python tools/import_branding.py "path/to/Casino_Anomaly_Branding_Design_4(1).zip" --commit
    git push origin dev

The initial import preparation intentionally retains the old branding
until the six real binaries can be copied into Git. The tool refuses
modified artwork, unexpected source context or conflicting new files;
it validates all inputs before changing project files. After import,
verify with python tools/import_branding.py --verify. The cinematic
presentation image remains in the source tree but is excluded from the
game export and never loaded by the UI. The README change is limited
to the existing icon paragraph; no redesign or merge is performed.

In-game review: normal and high UI scale, intro and return fades,
loading card, taskbar and Explorer executable icon, updater window.
Godot QA and Windows build must pass on the final integration commit.
