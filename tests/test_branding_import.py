"""Check the Phase 6 import plan against the actual checked-out source."""
import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("branding_import", ROOT / "tools/import_branding.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class BrandingImportTests(unittest.TestCase):
    def test_exact_package_rejects_missing_or_changed_assets(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "invalid.zip"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("casino_anomaly_logo.png", b"not the approved image")
            with self.assertRaises(ValueError):
                MODULE.read_package(path)

    def test_source_plan_or_integrated_tree(self):
        if not (ROOT / MODULE.OLD).exists():
            MODULE.verify(ROOT)
            return
        edits = MODULE.plan(ROOT)
        self.assertEqual(set(MODULE.SOURCE_FILES),
                         {p for p in edits if not p.endswith(".import")})
        old_menu = (ROOT / "ui/menu.tscn").read_text(encoding="utf-8")
        marker = '[node name="CenterPanel"'
        self.assertEqual(old_menu[old_menu.index(marker):],
                         edits["ui/menu.tscn"][edits["ui/menu.tscn"].index(marker):])
        self.assertIn("casino_anomaly_logo.png", edits["ui/menu.tscn"])
        self.assertIn("config/windows_native_icon", edits["project.godot"])
        self.assertIn("application/icon=\"res://branding/casino_anomaly.ico\"",
                      edits["export_presets.cfg"])
        for path, contents in edits.items():
            self.assertNotIn(MODULE.OLD, contents, path)
            if path.endswith(".import"):
                self.assertIn("compress/mode=0", contents)
                self.assertIn("mipmaps/generate=true", contents)
        self.assertEqual(len([p for p in edits if p.endswith(".import")]), 4)
        self.assertTrue((ROOT / MODULE.OLD).exists())  # planning is read-only


if __name__ == "__main__":
    unittest.main()
