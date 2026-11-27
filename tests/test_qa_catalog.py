import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class QACatalogTests(unittest.TestCase):
    def test_every_script_is_classified_and_no_duplicate_invocations(self):
        groups = json.loads((ROOT / "tools/qa_groups.json").read_text(encoding="utf-8"))
        entries = [item for group in groups.values() for item in group]
        pairs = [(item["script"], item.get("suite")) for item in entries]
        self.assertEqual(len(pairs), len(set(pairs)))
        self.assertEqual({item["script"] for item in entries},
                         {p.relative_to(ROOT).as_posix() for p in (ROOT / "tests").glob("*.gd")})
        for item in entries:
            self.assertTrue(item["marker"].endswith("PASS") or "QA PASS:" in item["marker"])
            self.assertGreater(item.get("seconds", 120), 0)


if __name__ == "__main__":
    unittest.main()
