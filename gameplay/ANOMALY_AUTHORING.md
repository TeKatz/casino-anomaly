# Casino Anomaly — Profile, archive and anomaly authoring

## Adding new anomalies

The source of truth for anomalies is the folder
`res://gameplay/anomaly_definitions/`, not a hand-maintained list.

1. Implement a reversible handler (a `RefCounted` script with
   `can_apply(room, definition)`, `apply(room, definition)`, `clear()`)
   or reuse an existing handler in `gameplay/anomalies/`.
2. Duplicate an existing `.tres` in `gameplay/anomaly_definitions/`,
   set a unique, permanent `id`, the corresponding `handler` script,
   target, both language titles/descriptions and both categories.
3. Keep `enabled = true` (default). Setting `discoverable = false`
   excludes an available effect from player collection progress.
4. For optional effect parameters such as `position_offset`, set the
   corresponding `has_position_offset` boolean before setting the value.
5. Run `tests/anomaly_variations_qa.gd` and `tests/profile_archive_qa.gd`.
   Ensure every effect is visible, reversible and valid for its target room.

Godot 4.5 `ResourceLoader.list_directory()` discovers every `.tres`
resource automatically in editor **and packaged exports**. The catalog
sorts and validates definitions, detects duplicate/empty IDs and
missing translations, and exposes the same definitions to gameplay,
developer picker, archive and profile progress. No source-code catalog
registration or hard-coded anomaly counts need to be updated.

**Stable IDs are save-game contracts.** You may change descriptions,
categories, tuning or handlers, but do not rename an existing ID without
an explicit migration. Disabled/deleted entries remain in player saves
but are not counted against the current active catalog denominator.
The archive deliberately hides **names, descriptions and categories** until
the player correctly identifies the effect. A wrong choice records a
non-identifying encounter only; correct identification unlocks the full
entry. The most recent review and the physical corridor plaque display
only a neutral result (irregular/clear), never the effect ID or details.

## Profile and run persistence

There are five independent slots:

- `user://profiles/slot_01/profile.cfg` — name and profile version
- `user://profiles/slot_01/run.cfg` — current 12-room run
- `user://profiles/slot_01/progress.cfg` — collection IDs, historical
  decisions (last 20), records and lifetime statistics

Repeat for `slot_02` through `slot_05`. The *active catalog* is
always derived from installed definitions, rather than stored in saves.
Starting a new run only resets `run.cfg` and keeps `progress.cfg`.
Debug-forced rooms never create player discoveries or statistics.

The former `user://anomaly_run.cfg` is imported into an empty slot 1
once, leaving the original file intact as a backup. A migration marker
prevents an intentionally deleted profile from being recreated at the
next startup. The menu owns the choice of the active profile; the
`LoopState` autoload may only write that slot's active run.

New progress fields can be introduced with defaults in the reader.
If the saved format ever changes incompatibly, bump the appropriate
version and add a migration rather than deleting existing progress.


## Room distribution (Classic)

Classic uses a 65% base anomaly chance, raised to 75% / 88% after one / two consecutive normal rooms and lowered to 45% after three or more consecutive anomalies. With eligible anomalies, a fourth consecutive normal room is forbidden and the rolling 12-room window contains at least seven anomalies (including the mandatory clean first room). The last eleven organically resolved room types persist in the run save and survive incorrect answers, reloads and room handoffs. Debugged rooms are excluded; an empty available pool takes precedence over the quota, and older saves only recover the known normal streak. Other modes, rarity weights, family repeat prevention, variants, discovery preference and achievements are unchanged. The ten-normal-chain achievement remains attainable outside Classic (e.g. Endless or Time Trial).
