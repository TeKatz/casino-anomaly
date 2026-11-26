"""Execute all tests in a named QA group; a failure never skips its peers."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
GROUPS = json.loads((ROOT / "tools/qa_groups.json").read_text(encoding="utf-8"))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("godot")
    parser.add_argument("group", nargs="+", choices=GROUPS, help="One or more catalog groups; all selected tests run")
    parser.add_argument("--logs", required=True)
    args = parser.parse_args()
    logs = Path(args.logs).resolve()
    logs.mkdir(parents=True, exist_ok=True)
    results = []
    if len(set(args.group)) != len(args.group):
        parser.error("Each QA group may be selected only once")
    for group in args.group:
        print(f"QA group: {group}", flush=True)
        for spec in GROUPS[group]:
            name = Path(spec["script"]).stem + ("-" + spec["suite"] if "suite" in spec else "")
            cmd = [sys.executable, str(ROOT / "tools/run_godot_qa.py"),
                   args.godot, spec["script"], spec["marker"],
                   "--seconds", str(spec.get("seconds", 120)), "--log", str(logs / (name + ".log"))]
            if "suite" in spec:
                cmd += ["--suite", spec["suite"]]
            if spec.get("editor"):
                cmd.append("--editor")
            print(f"::group::{name}", flush=True)
            # Isolate persistent saves, settings and editor user data per test.
            with tempfile.TemporaryDirectory(prefix="casino-qa-") as user_dir:
                env = os.environ.copy()
                for key in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "APPDATA"):
                    directory = Path(user_dir) / key
                    directory.mkdir()
                    env[key] = str(directory)
                try:
                    status = subprocess.run(cmd, cwd=ROOT, env=env, timeout=spec.get("seconds", 120)+30).returncode
                except (OSError, subprocess.TimeoutExpired) as exc:
                    print(f"QA runner failed: {exc}", flush=True)
                    status = 1
            results.append((name, status))
            print("::endgroup::", flush=True)
            print(f"{name}: {'PASS' if status == 0 else 'FAIL'}", flush=True)
    summary = ["| Test | Result |", "| --- | --- |"] + [
        f"| {name} | {'PASS' if code == 0 else 'FAIL'} |" for name, code in results
    ]
    report = "\n".join(summary) + "\n"
    (logs / "summary.md").write_text(report, encoding="utf-8")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as out:
            out.write(f"### QA: {', '.join(args.group)}\n" + report)
    print(report, flush=True)
    return int(any(code != 0 for _, code in results))

if __name__ == "__main__":
    sys.exit(main())
