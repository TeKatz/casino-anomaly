# Anomaly pack 02 — quiet horror

Exactly ten new discoverable families and definitions, no variants. Pack 01 approved and untouched. No new audio, sudden reveals, flashing lights, camera overrides, player effects, collisions, or changes to spawn weights, saves or the catalogue UI. Every effect is reversible and private to the room.

| ID | Manual review |
|---|---|
| `synchronized_busts` | Both marble busts slowly turn in unison, as though following an unseen presence. |
| `inverted_cat` | The concrete cat hangs upside down above its pedestal. |
| `lightless_horse` | The horse statue absorbs light and appears as a solid black silhouette. |
| `watching_canvases` | The three paintings show pale eyes in otherwise black canvases. |
| `stay_here` | The entrance, bar and table signs all carry the same unsettling message: STAY HERE. |
| `last_kings` | All chess pieces except the two kings are gone. |
| `ownerless_shadow` | A long human-shaped shadow lies on the entrance carpet, without anyone casting it. |
| `empty_footsteps` | Dark barefoot impressions cross the long carpet and end abruptly. |
| `crimson_hall` | The main corridor lamps bathe the casino in a steady unnatural red light. |
| `silent_countdown` | All entrance slot machine titles display the same silently decreasing countdown. |

The two animations respect reduced motion. The busts oscillate gently over 12 seconds; the countdown starts at 01:00, stops at zero and has no consequence. Both remain identifiable with motion disabled. Floor decals use locally generated original SVG imagery, without extra import dependencies. The visual quality and placement need in-game review, including both streamed orientations and GI modes. The existing CI anomaly regression verifies registration, target counts, application, isolation and cleanup.

## Visual review 1

13, 16 and 19 accepted unchanged. 11 rotates around the measured local mesh bounds base center; 12 replaces inverted cat with both animal statues missing (stable ID retained); 14 blinks with staggered 5.5-second cycles; 15 slow red pulse; 17 softer, elongated shadow silhouette with graded opacity; 18 28 sequential fading footprints, velocity-adaptive with slow idle pace; 20 one spatial, low-level HORROR bus synthesized tick per second, stopping at zero. No new families, assets or changes to player movement. Visual approval remains pending.

## Visual review 2

Seven effects accepted (11–16 and 19). 17 replaces the drawn SVG with an isolated one-shot render of the existing licensed croupier model in its idle pose, projected onto the carpet with a soft opacity shader. No actual NPC/light/collider in the hall; model import required. 18 rotates the footprint texture 180 degrees so toes agree with the existing travel order; tempo/fade unchanged. 20 raises the spatial tick to -9 dB with 22m reach and a stronger damped waveform; the timer now ticks independent of reduced visual motion and honors the HORROR mixer. Tests check direction, projection structure, playback invocation, isolation and cleanup. Actual render and audibility require manual review.
