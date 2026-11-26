# Casino Anomaly CI

The automatic CI workflow is `.github/workflows/development-release.yml` (dev pushes, PRs into dev/main). It exposes five checks: Python QA, Linux QA, Windows QA, Windows Build (including updater contract tests), and Development Release. All ten QA catalog groups are retained but execute within two platform jobs. Each imports the project once, and every selected script runs in its own Godot process with isolated user data, timeout, and log. A nonzero test result never prevents later groups from executing. A broken shared project import is an actual prerequisite failure. Linux and Windows archives are pinned and cached; Windows QA and Build use the same cache key, so only a cold cache can require two independent Windows downloads. Build is independent of all QA jobs; only publication requires all four prerequisite jobs to succeed. Older commits cannot replace newer releases. Superseded QA and build jobs are cancelled per branch, not publication.

The catalog `tools/qa_groups.json` assigns each GDScript exactly once, except anomaly_variations_qa.gd which has four distinct suites. Python tests validate inventory coverage. New tests must be added to the catalog. The two historical editor-placement tests, the previously unregistered UI design baseline, and the original standalone Backrooms sketch geometry contract are retained as opt-in diagnostics (Actions > Casino Anomaly Manual Diagnostics > Run workflow). They encode old authored layout assumptions or isolated editor behavior and do not block normal release; other UI, editor, collision, geometry, and traversal regressions are still required. Headless testing does not certify actual GPU visuals.

No old test script was deleted. Removed duplicate or one-time workflow entry points:
- architecture-qa.yml
- artist-layout-regression-qa.yml
- audio-loop-qa.yml
- backrooms-layout-qa.yml
- backrooms-traversal-qa.yml
- controls-settings-qa.yml
- croupier-intro-qa.yml
- first-loop-gameplay-qa.yml
- full-room-editor-qa.yml
- interior-qa.yml
- major-events-qa.yml
- model-source-probe.yml
- probe-new-assets.yml
- spatial-qa.yml
- streaming-qa.yml
- visual-editor-qa.yml
Their contents remain in Git history; asset import and bake tools remain available. Backrooms asset import and texture preparation are manual maintenance workflows, not QA. CI never pushes source changes: apply signature-bottle migration or tutorial bake deliberately when required, review and commit the generated files before release.

Run individual groups locally:
```sh
python tools/run_qa_group.py /path/to/godot baseline flood other_side --logs qa-logs
python -m unittest discover -s tests -p 'test_*.py'
```

Godot's exact shutdown resource-retention diagnostic is reported as a warning after an exact PASS marker on Windows and Linux, and never overrides a nonzero exit, timeout, or actual runtime error. Linux full-asset CI confirmed the same shutdown diagnostic (baseline, Flood, Silent Audience, croupier intro). Resource lifetime remains a separate unresolved issue; the warning and full logs are retained.

Windows headless renderer regressions: the asynchronous SceneLoader request disables nested worker loading only on headless displays; real GPU loading is unchanged. Loading and prop fixtures now wait for disposal; real editor tests wait for filesystem scan completion. Exact, observed Windows headless shutdown RID diagnostics are warning-only for the two editor scripts and the prop script after their PASS markers. Runtime RID initialization errors, other scripts, unrecognized RID types, nonzero exits and timeouts remain fatal. These warning exceptions are diagnostic debt, not evidence of a resolved engine resource leak.
