"""Run Godot QA with live output, fail-fast diagnostics and a hard wall-clock limit."""
import argparse
import re
import subprocess
import sys
import threading
from pathlib import Path

# Godot 4.5.1 Dummy renderer/editor shutdown diagnostics seen in CI.
# Scope by exact test and only after PASS; never allow actual runtime errors.
_EDITOR_SHUTDOWN_RIDS = (
    "N16RendererViewport8ViewportE",
    "PN13RendererDummy14TextureStorage12DummyTextureE",
    "N17RendererSceneCull8ScenarioE",
    "PN18TextServerAdvanced22ShapedTextDataAdvancedE",
    "PN18TextServerAdvanced12FontAdvancedE",
)


def known_renderer_shutdown(clean, script, editor):
    allowed = ()
    if editor and script in ("tests/sketchfab_true_editor_qa.gd",
                             "tests/voxel_gi_editor_preview_qa.gd"):
        allowed = _EDITOR_SHUTDOWN_RIDS
    match = re.fullmatch(r"ERROR: \d+ RID allocations? of type '([^']+)' (?:was|were) leaked at exit\.", clean)
    return match is not None and match.group(1) in allowed


def classify_line(line, expected, passed, platform, script="", editor=False):
    """Return (success marker seen, fatal error, shutdown diagnostic)."""
    clean = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", line).strip()
    passed = passed or clean == expected
    shutdown = (
        passed and platform in ("win32", "linux") and re.fullmatch(
            r"ERROR: \d+ resources? still in use at exit \(run with --verbose for details\)\.?",
            clean,
        ) is not None
    )
    shutdown = shutdown or (passed and platform == "win32" and
                            known_renderer_shutdown(clean, script, editor))
    fatal = not shutdown and bool(re.search(
        r"SCRIPT ERROR:|Parse Error:|Failed to load|^ERROR:", clean
    ))
    return passed, fatal, shutdown


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("godot")
    parser.add_argument("script")
    parser.add_argument("expected")
    parser.add_argument("--suite")
    parser.add_argument("--editor", action="store_true")
    parser.add_argument("--log", default="godot-qa.log")
    parser.add_argument("--seconds", type=int, default=300)
    args = parser.parse_args()
    cmd = [args.godot, "--headless", "--path", ".", "--script", "res://" + args.script]
    # Temporary investigation: identify the remaining shutdown objects
    # in existing fixtures, without adding test runs or changing pass rules.
    if args.script in ("tests/grand_entrance_hall_qa.gd", "tests/menu_visual_qa.gd",
                       "tests/sketchfab_true_editor_qa.gd"):
        cmd.insert(1, "--verbose")
    if args.editor:
        cmd.insert(1, "--editor")
    if args.suite:
        cmd += ["--", args.suite]
    print("QA start:", args.script, args.suite or "", flush=True)
    failed = False
    passed = False
    expired = threading.Event()
    with Path(args.log).open("w", encoding="utf-8") as log, subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding="utf-8", errors="replace", bufsize=1
    ) as proc:
        def kill_on_timeout():
            if proc.poll() is None:
                expired.set()
                proc.kill()
        timer = threading.Timer(args.seconds, kill_on_timeout)
        timer.start()
        try:
            for line in proc.stdout:
                print(line, end="", flush=True)
                log.write(line)
                log.flush()
                passed, fatal, shutdown = classify_line(line, args.expected, passed, sys.platform, args.script, args.editor)
                if shutdown:
                    print("::warning::Godot shutdown resource/RID diagnostic after successful QA; investigate cleanup separately.", flush=True)
                failed |= fatal
            code = proc.wait()
        finally:
            timer.cancel()
            timer.join()
    if expired.is_set():
        print(f"QA TIMEOUT after {args.seconds}s: {args.script} {args.suite or ''}", flush=True)
    if expired.is_set() or failed or code != 0 or not passed:
        print(f"QA FAILED: {args.script}, exit={code}, error={failed}, marker={passed}", flush=True)
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
