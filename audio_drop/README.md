# Casino Anomaly - Seamless sound package

The uploaded WAV/OGG files were inspected and rendered as gapless Ogg Vorbis
loops with head/tail crossfades:

| Pack entry | Usage | Crossfade | Loop duration |
| --- | --- | --- | --- |
| hmm_menu_seamless.ogg | Main menu ONLY | 4.0 s | 92.754 s |
| casino_room_tone_seamless.ogg | Persistent ambience; all scenes | 1.6 s | 13.219 s |

Original music: Xythe, hmm.wav, Freesound #115831
https://freesound.org/people/Xythe/sounds/115831/
Its Freesound listing specifies CC0. The room tone was supplied by the user
without embedded rights metadata; verify original license before redistribution.

## One-time source import

Download casino_anomaly_seamless_audio.zip from the ChatGPT response.
Upload the single ZIP to audio_drop/casino_anomaly_seamless_audio.zip on dev.
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
tutorial, resumed casino hall or 3D preview, and keeps its playback position
when another hall/player is loaded. Returning to menu stops ambience immediately
and restores the music-only state. The controller continues using the existing
Music and SFX volume settings.
