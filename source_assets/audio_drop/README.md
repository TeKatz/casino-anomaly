# Casino Anomaly - Seamless sound package

The uploaded WAV/OGG files were inspected and rendered as gapless Ogg Vorbis
loops with head/tail crossfades:

| Pack entry | Usage | Crossfade | Loop duration |
| --- | --- | --- | --- |
| hmm_menu_seamless.ogg | Main menu ONLY | 4.0 s | 92.754 s |
| casino_room_tone_seamless.ogg | Persistent ambience; all scenes | 1.6 s | 13.219 s |

Original menu music: "hmm.wav" by Xythe, Freesound #115831, CC0 1.0.
https://freesound.org/people/Xythe/sounds/115831/
Original room ambience: "Room Tone In An Apartment Living Room 2" by leonelmail,
Freesound #329533, CC0 1.0.
https://freesound.org/people/leonelmail/sounds/329533/
The user-provided recording was crossfaded into the continuous in-game loop.
Both original Freesound listings identify their sounds as CC0.

## One-time source import

Download casino_anomaly_seamless_audio.zip from the ChatGPT response.
Upload the single ZIP to source_assets/audio_drop/casino_anomaly_seamless_audio.zip on dev.
It contains both processed Ogg tracks, a hash manifest and source credits.

The Development build runs: python tools/import_audio.py
Run the same command locally before opening Godot to preview the new audio.
No sound files are downloaded at runtime.

Archive SHA-256:
51fda271b62575657d86a11390879db8f7f6468f3ea7166298045ff70a9d6d44

Godot paths:
res://audio/hmm_menu_seamless.ogg
res://audio/casino_room_tone_seamless.ogg

Without the source ZIP, the AudioDirector is safe and silent; the test is a
compatibility check only. Once it is uploaded, tests verify the real streams.
Music uses the MUSIC volume setting; ambient tone uses the SFX volume setting.

## Correct playback scope

The main menu plays only the crossfaded hmm music track. The persistent
AudioDirector never auto-plays white noise on project startup. Ambient tone
begins when the actual first-person Player enters the world, whether in the
tutorial, resumed casino hall, and keeps its playback position
when another hall/player is loaded. Returning to menu stops ambience immediately
and restores the music-only state. The controller continues using the existing
Music and SFX volume settings.
