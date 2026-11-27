"""Regression tests for the Godot QA log classifier."""
import unittest
from tools.run_godot_qa import classify_line


class LogClassifierTests(unittest.TestCase):
    marker = "Casino Anomaly ten subtle anomalies QA PASS"
    leak = "ERROR: 2 resources still in use at exit (run with --verbose for details)."

    def classify(self, line, passed=True, platform="win32"):
        return classify_line(line, self.marker, passed, platform)

    def test_exact_windows_log(self):
        self.assertEqual(self.classify(self.leak + "\r\n"), (True, False, True))

    def test_ansi_windows_log(self):
        self.assertEqual(self.classify("\x1b[31;1m" + self.leak + "\x1b[0m\n"), (True, False, True))

    def test_other_resource_count(self):
        self.assertEqual(self.classify(self.leak.replace("2 resources", "1 resource")), (True, False, True))

    def test_no_marker_yet(self):
        self.assertEqual(self.classify(self.leak, passed=False), (False, True, False))

    def test_linux_known_shutdown_diagnostic(self):
        self.assertEqual(self.classify(self.leak, platform="linux"), (True, False, True))
        self.assertEqual(self.classify(self.leak, passed=False, platform="linux"), (False, True, False))
        self.assertEqual(self.classify("ERROR: unrelated error", platform="linux"), (True, True, False))

    def test_real_errors_stay_fatal(self):
        for line in ("ERROR: failed", "SCRIPT ERROR: invalid value", "Parse Error: invalid syntax",
                     "Failed to load scene", self.leak + " additional error"):
            with self.subTest(line=line):
                self.assertEqual(self.classify(line), (True, True, False))

    def test_editor_shutdown_is_narrowly_scoped(self):
        leak = "ERROR: 6 RID allocations of type 'N16RendererViewport8ViewportE' were leaked at exit."
        script = "tests/sketchfab_true_editor_qa.gd"
        self.assertEqual(classify_line(leak, self.marker, True, "win32", script, True), (True, False, True))
        self.assertEqual(classify_line(leak, self.marker, False, "win32", script, True), (False, True, False))
        self.assertEqual(classify_line(leak, self.marker, True, "win32", script, False), (True, True, False))
        self.assertEqual(classify_line(leak, self.marker, True, "win32", "tests/smoke.gd", True), (True, True, False))
        self.assertEqual(classify_line(leak.replace("N16RendererViewport8ViewportE", "unknown"), self.marker, True, "win32", script, True), (True, True, False))

    def test_prop_shutdown_is_narrowly_scoped(self):
        script = "tests/prop_visuals_qa.gd"
        for leak in (
            "ERROR: Pages in use exist at exit in PagedAllocator: N20RasterizerSceneDummy21GeometryInstanceDummyE",
            "ERROR: 16 RID allocations of type 'N13RendererDummy9DummyMeshE' were leaked at exit.",
        ):
            self.assertEqual(classify_line(leak, self.marker, True, "win32", script), (True, False, True))
            self.assertEqual(classify_line(leak, self.marker, False, "win32", script), (False, True, False))
            self.assertEqual(classify_line(leak, self.marker, True, "win32", "tests/smoke.gd"), (True, True, False))

    def test_loading_renderer_errors_are_never_downgraded(self):
        for line in ('ERROR: Attempting to initialize the wrong RID',
                     'ERROR: Parameter "mem" is null.',
                     'ERROR: unimplemented base type encountered in renderer scene cull'):
            self.assertEqual(classify_line(line, self.marker, True, "win32",
                                           "tests/loading_transition_qa.gd"), (True, True, False))

    def test_marker_is_exact(self):
        self.assertEqual(self.classify(self.marker, passed=False), (True, False, False))
        self.assertEqual(self.classify("ERROR: " + self.marker, passed=False), (False, True, False))


if __name__ == "__main__":
    unittest.main()
