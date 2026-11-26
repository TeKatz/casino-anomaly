"""Prove that one failing group member cannot suppress the remaining tests."""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from tools import run_qa_group

class QAGroupTests(unittest.TestCase):
    def test_failure_does_not_skip_next_test_and_userdata_is_isolated(self):
        group = [
            {"script": "tests/first.gd", "marker": "FIRST PASS"},
            {"script": "tests/second.gd", "marker": "SECOND PASS", "editor": True},
        ]
        calls = []
        def fake_run(cmd, **kwargs):
            calls.append((cmd, kwargs["env"]["APPDATA"], kwargs["env"]["XDG_DATA_HOME"]))
            return subprocess.CompletedProcess(cmd, 1 if len(calls) == 1 else 0)
        with tempfile.TemporaryDirectory() as logdir:
            with patch.object(run_qa_group, "GROUPS", {"test": group}), \
                    patch.object(run_qa_group.subprocess, "run", side_effect=fake_run), \
                    patch("sys.argv", ["run_qa_group.py", "godot", "test", "--logs", logdir]), \
                    patch.dict(os.environ, {"GITHUB_STEP_SUMMARY": ""}):
                self.assertEqual(run_qa_group.main(), 1)
            self.assertEqual(len(calls), 2)
            self.assertNotEqual(calls[0][1], calls[1][1])
            self.assertNotEqual(calls[0][2], calls[1][2])
            self.assertIn("--editor", calls[1][0])
            summary = (Path(logdir) / "summary.md").read_text(encoding="utf-8")
            self.assertIn("| first | FAIL |", summary)
            self.assertIn("| second | PASS |", summary)
