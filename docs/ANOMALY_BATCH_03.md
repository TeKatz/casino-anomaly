# Pack 03 — Broken Reality

Pack 01 and 02 accepted by player; unchanged. Ten new definitions, no extra variants. Force each ID through the developer menu and verify in normal/reversed halls, with reduced motion and graphics variants. No jump scares, new loud sounds, physical obstructions or global gameplay changes.

| ID | Test |
|---|---|
| `unfinished_game` | A roulette ball circles the stationary wheel without ever slowing down. |
| `invisible_dealer` | Eight cards slide from a deck across the table and gather themselves again. |
| `breathing_wall` | The wall slowly bulges and contracts as if breathing. |
| `forgotten_door` | An unfamiliar weathered door stands against the entrance wall. |
| `against_gravity` | Liquid droplets rise from four bottles towards the ceiling. |
| `pendulum` | A chandelier swings slowly, with its associated light moving in sync. |
| `black_bloom` | A dark organic stain spreads and contracts on the wall. |
| `extra_guest` | A motionless person sits in the lounge, their face obscured by darkness. |
| `wrong_reflection` | A framed painting becomes a mirror reflecting a statue that is absent from the room. |
| `they_are_listening` | Near the entrance cabinets the ambient sound and marquee lights slowly fade; they return when you leave. |

Implementation details: existing roulette model bounds drive a room-local ivory ball; existing eight cards animate along reversible paths; subdivided wall uses an animated vertex shader; door is decorative fitted geometry; four selected bottles emit rising faded drops; chandelier rotates around its upper bounds and moves the linked light; procedural stain shader; seated guest uses the original licensed sitting_idle clip; mirror replaces one painting canvas with a live reflected camera and reflection-only cat statue (layer masks restored); localized ambient attenuation around entrance cabinets also dims private strip materials. The mirror camera has an approximate near-plane clip and a limited update rate; check perspective and clipping visually. Audio attenuation preserves mixer preferences and room transition cleanup. Existing CI regression exercises registration, apply/restore and isolation plus selected animation and setup assertions. Runtime visual approval is pending.
