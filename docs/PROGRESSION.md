# Progression update

Profile XP and achievements are independent of the active run. Levels 1–100
use a cost of 150 + 25 × (level - 1) XP. Existing version-1 profile files
retain their records and history. The migration derives XP from recorded
normal/anomaly decisions, discoveries and classic completions. Unknown
historical details (e.g. flawless completions) are not fabricated.

The classic run.cfg is unchanged in location. Other modes save in
run_endless.cfg, run_nightmare.cfg, run_time_trial.cfg, run_research.cfg
and run_expedition.cfg. Deleting a profile deletes every mode save. Menu
mode selection and pause restart retain the selected ruleset.

Modes: classic 12 consecutive correct; endless ends at first mistake;
nightmare 12 flawless with hard variants weighted; time trial 12 rooms
with 20 seconds per error (active game time, saved at decisions and
pause-menu exit); research 20 rooms with no progress reset; expedition
reference hall followed by guaranteed existing Backrooms traversal.
Nightmare unlocks on first classic completion; expedition on discovery
of the Backrooms. Alternative modes skip the introduction. Local records
only, no network or Steam requirement. Developer-forced decisions award
nothing; assisted runs cannot earn competitive run records/bonuses.

The catalog has 14 stable family IDs, 16 authored variants and five
rarities. Families are weighted independently of variant count; variant
IDs persist with the run, and collection records aggregate by family.
After eight anomaly encounters without a first discovery, the next
anomalous draw favors an unidentified available family exclusively.
The ordinary clear-room probability is unchanged outside Research.
The archive reveals only identified families/forms; misses never expose
the anomaly name. Mastery levels are reached at 1, 3 and 5 identifications.
The UI uses stylized cards without fabricated screenshots.

48 localized achievements cover progression, skill, exploration, modes
and hidden milestones. No daily challenges, prestige or Steam integration
in this release. No new Backrooms maps are included.

Regression QA: tests/progression_qa.gd (migration, mode rules, save
isolation, XP, variants, debug exclusion, records and UI construction).
The normal Backrooms, streaming and profile archive tests remain enabled.
