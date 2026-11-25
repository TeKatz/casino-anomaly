# Anomaly batch 01 — manual review

Exactly 10 new families and 10 definitions; no additional variants. Existing selection, save data, weights, catalogue UI and room geometry are unchanged.

Force each ID using the developer anomaly menu. Compare to a normal room, make the correct decision, and inspect the following room for residue. Repeat with GI enabled/disabled when relevant and from both room orientations. Debug selections intentionally do not award archive progress; normal gameplay discovers these entries.

| ID | Effect |
|---|---|
| `blank_reels` | All three reel symbols on one entrance cabinet have disappeared. |
| `false_jackpot` | One entrance cabinet's illuminated title reads JACKPOT instead of its normal name. |
| `dark_marquee` | The illuminated marquee and title of one entrance cabinet are dark. |
| `watchful_camera` | The west security camera has turned sharply away from its normal direction. |
| `floating_hand` | Four playing cards hover above one card table. |
| `missing_hand` | Half the playing cards on the other card table have vanished. |
| `burgundy_felt` | The felt surface of one card table has turned burgundy. |
| `blue_runner` | The entrance runner has lost its usual color and pattern, turning deep blue. |
| `empty_reserve` | The liquid in several signature bottles on the bar has disappeared. |
| `bare_monstera` | The leaves of one of the lounge plants have disappeared. |

Targets are deterministic authored scene nodes; slot indices refer to visible revised cabinets in scene order. No new external assets or collision modifications. Runtime material overrides are private to the affected mesh. Only visual testing can establish clue readability and final tuning. The existing anomaly QA now also checks availability, effect, restoration and cross-room isolation for each new family.
