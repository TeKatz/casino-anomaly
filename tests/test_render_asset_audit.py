import json
import struct
import tempfile
import unittest
from pathlib import Path

from tools.audit_render_assets import audit, gltf_document, image_dimensions, mesh_metrics


class RenderAuditTest(unittest.TestCase):
    def test_triangle_modes_and_instances(self):
        doc = {"accessors": [{"count": 9}, {"count": 5}],
               "meshes": [{"primitives": [{"indices": 0}, {"attributes": {"POSITION": 1}, "mode": 5}]}],
               "nodes": [{"mesh": 0}, {"mesh": 0}]}
        result = mesh_metrics(doc)
        self.assertEqual(result["source_triangles"], 6)
        self.assertEqual(result["mesh_node_triangles"], 12)
        self.assertEqual(result["surfaces"], 2)

    def test_read_only_inventory_and_glb(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            models = root / "models"
            models.mkdir()
            raw = json.dumps({"meshes": [], "nodes": []}).encode()
            raw += b" " * (-len(raw) % 4)
            glb = models / "example.glb"
            glb.write_bytes(struct.pack("<4sII", b"glTF", 2, 20 + len(raw)) +
                            struct.pack("<I4s", len(raw), b"JSON") + raw)
            self.assertEqual(gltf_document(glb)["nodes"], [])
            png = b"\x89PNG\r\n\x1a\n" + struct.pack(">I4sII", 13, b"IHDR", 128, 64)
            (models / "a.png").write_bytes(png)
            (models / "b.png").write_bytes(png)
            (models / "a.png.import").write_text("mipmaps/generate=true\ncompress/mode=2\n")
            result = audit(root)
            self.assertEqual(image_dimensions(models / "a.png"), (128, 64))
            self.assertEqual(len(result["meshes"]), 1)
            self.assertEqual(len(result["identical_source_textures"]), 1)
            self.assertEqual(result["textures"][0]["import"]["compress/mode"], "2")
            self.assertFalse(result["errors"])
            self.assertEqual((models / "a.png").read_bytes(), png)


if __name__ == "__main__":
    unittest.main()
