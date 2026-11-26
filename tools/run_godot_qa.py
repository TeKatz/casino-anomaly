"""Run Godot QA with live output, fail-fast diagnostics and a hard wall-clock limit."""
import argparse
import re
import subprocess
import sys
import threading
from pathlib import Path

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("godot")
    parser.add_argument("script")
    parser.add_argument("expected")
    parser.add_argument("--suite")
    parser.add_argument("--log", default="godot-qa.log")
    parser.add_argument("--seconds", type=int, default=300)
    args = parser.parse_args()
    cmd = [args.godot, "--headless", "--path", ".", "--script", "res://" + args.script]
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
                passed |= args.expected in line
                if re.search(r"SCRIPT ERROR:|Parse Error:|Failed to load|^ERROR:", line):
                    failed = True
                    # Preserve subsequent stack trace output; watchdog bounds a stuck process.
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
