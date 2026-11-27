# Pack 03 — Broken Reality

Pack 01 and 02 accepted by player; unchanged. Originally ten definitions, no extra variants. The 2026-11-27 catalog audit retired `breathing_wall`; nine remain active. Force each ID through the developer menu and verify in normal/reversed halls, with reduced motion and graphics variants. No jump scares, new loud sounds, physical obstructions or global gameplay changes.

| ID | Test |
|---|---|
| `unfinished_game` | A roulette ball circles the stationary wheel without ever slowing down. |
| `invisible_dealer` | Eight cards slide from a deck across the table and gather themselves again. |
| `forgotten_door` | An unfamiliar weathered door stands against the entrance wall. |
| `against_gravity` | Liquid droplets rise from four bottles towards the ceiling. |
| `pendulum` | A chandelier swings slowly, with its associated light moving in sync. |
| `black_bloom` | A dark organic stain spreads and contracts on the wall. |
| `extra_guest` | A motionless person sits in the lounge, their face obscured by darkness. |
| `wrong_reflection` | A framed painting becomes a mirror reflecting a statue that is absent from the room. |
| `they_are_listening` | Near the entrance cabinets the ambient sound and marquee lights slowly fade; they return when you leave. |

Implementation details: existing roulette model bounds drive a room-local ivory ball; existing eight cards animate along reversible paths; door is decorative fitted geometry; four selected bottles emit rising faded drops; chandelier rotates around its upper bounds and moves the linked light; procedural stain shader; seated guest uses the original licensed sitting_idle clip; mirror replaces one painting canvas with a live reflected camera and reflection-only cat statue (layer masks restored); localized ambient attenuation around entrance cabinets also dims private strip materials. The mirror camera has an approximate near-plane clip and a limited update rate; check perspective and clipping visually. Audio attenuation preserves mixer preferences and room transition cleanup. Existing CI regression exercises registration, apply/restore and isolation plus selected animation and setup assertions. Runtime visual approval is pending.

## Visual review 1

26 accepted unchanged. 21 ball lowered 8cm; 22 both tables with offset cycles; 23 stronger wider deformation; 24 moved off streaming-hidden entrance wall; 25 upper Signature_3 row, isolated rigid bodies with negative gravity, ceiling rebound, five-second lifetime and capped count; 27 enlarged 11.5m stain; 28 narrower guest, matte suit, black head mask; 29 new eye-height mirror with off-axis viewport frustum and explicit clipping, no wall layer mutation; 30 stronger light attenuation and screen blur/vignette below HUD, reduced motion disables blur. Visual/audio confirmation still required. No new families.

## Phase 4C: animation extensions

- Extra Guest: the retained suited character uses anatomical direction transfer from the original Croupier sitting-idle clip. Only selected head/eye material surfaces receive a bone-aligned face mask. Pose-local capsule shapes are removed with the effect.
- Forgotten Door: proximity-driven hinge and moving leaf collider, opaque black recess behind the leaf, unchanged solid original wall. The optional knock is intentionally silent until a reviewed asset is supplied.
- Unfinished Game: original render geometry is partitioned locally; ball slows, moves toward the pockets and climbs back outward without teleporting. Original source visibility is restored on clear. Rotor partition and visual fit require in-game inspection.

### Audio integration pending

Provide a licensed, non-looping, quiet mono knock as `audio/anomalies/forgotten_door_knock.ogg`; the door script loads it only when available and uses the existing HORROR bus, irregular 13–29 s intervals and positional attenuation. Add its source/license to asset credits before shipping. No replacement sound is included. No suitable verified roulette rolling/contact clip was found; leave those cues disabled until reviewed assets are supplied.
