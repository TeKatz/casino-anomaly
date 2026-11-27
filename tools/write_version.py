#!/usr/bin/env python3
"""Generate the version embedded into each published Godot PCK."""
import json
import os
from pathlib import Path

run_number = int(os.environ["GITHUB_RUN_NUMBER"])
sha = os.environ["PUBLISHED_COMMIT"]
version = f"0.1.0-dev.{run_number}"
Path("version.json").write_text(
    json.dumps({
        "version": version,
        "versionCode": run_number,
        "channel": "development",
        "commit": sha,
    }, indent=2) + "\n",
    encoding="utf-8",
)
print("Building", version, sha)
