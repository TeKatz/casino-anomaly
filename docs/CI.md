# Casino Anomaly CI

The single automatic CI workflow is `.github/workflows/development-release.yml` (dev pushes, PRs into dev/main). It runs independent Python tooling tests, six Linux groups and a Windows build with all remaining runtime/editor regressions. Linux jobs share a pinned, cached Godot archive; matrix fail-fast is disabled. A failure does not cancel another group or skip the other scripts in the same group. A broken project import is an actual prerequisite failure. Each script gets a separate Godot process, user data, timeout and log. The Windows build is still available as an artifact if Linux fails; public publication waits for all mandatory groups and the successful Windows build. Older commits cannot replace newer releases.

The catalog `tools/qa_groups.json` assigns each GDScript exactly once, except anomaly_variations_qa.gd which has four distinct suites. Python tests validate inventory coverage. New tests must be added to the catalog. The two historical editor-placement tests and the original standalone Backrooms sketch geometry contract are retained as opt-in diagnostics (Actions > Run workflow > diagnostics). They encode old authored layout assumptions or isolated editor behavior and do not block normal release; other editor, collision, geometry, and traversal regressions are still required. Headless testing does not certify actual GPU visuals.

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
python tools/run_qa_group.py /path/to/godot baseline --logs qa-logs
python -m unittest discover -s tests -p 'test_*.py'
```
