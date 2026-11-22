"""Regression: re-extracting a Sketchfab model keeps adjacent Godot .import IDs."""
import json
import tempfile
import unittest
import zipfile
from pathlib import Path
from tools import import_tutorial_sketchfab as importer


class TutorialImportSidecarsTest(unittest.TestCase):
    def test_reimport_preserves_matching_sidecars_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            original_out = importer.OUT
            importer.OUT = base / "models"
            try:
                dest = importer.OUT / "fixture"
                (dest / "textures").mkdir(parents=True)
                (dest / "scene.gltf").write_text("old content", encoding="utf-8")
                (dest / "scene.gltf.import").write_text(
                    "uid=\"uid://stable-scene\"\n", encoding="utf-8"
                )
                (dest / "textures" / "main.png").write_bytes(b"old")
                (dest / "textures" / "main.png.import").write_text(
                    "uid=\"uid://stable-texture\"\n", encoding="utf-8"
                )
                (dest / "textures" / "removed.png.import").write_text(
                    "uid=\"uid://orphan\"\n", encoding="utf-8"
                )
                archive = base / "model.zip"
                with zipfile.ZipFile(archive, "w") as file:
                    file.writestr("glTF/scene.gltf", json.dumps({
                        "asset": {"version": "2.0"},
                        "images": [{"uri": "textures/main.png"}]
                    }))
                    file.writestr("glTF/textures/main.png", b"new")
                    file.writestr("glTF/textures/additional.png", b"extra")
                importer.install(archive, "fixture")
                self.assertTrue((dest / "scene.gltf").exists())
                self.assertEqual((dest / "textures" / "main.png").read_bytes(), b"new")
                self.assertEqual(
                    (dest / "scene.gltf.import").read_text(encoding="utf-8"),
                    'uid="uid://stable-scene"\n'
                )
                self.assertEqual(
                    (dest / "textures" / "main.png.import").read_text(encoding="utf-8"),
                    'uid="uid://stable-texture"\n'
                )
                self.assertFalse((dest / "textures" / "removed.png.import").exists())
                self.assertFalse((dest / "textures" / "additional.png.import").exists())
            finally:
                importer.OUT = original_out


if __name__ == "__main__":
    unittest.main()
