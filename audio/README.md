# Runtime-generated audio files

The binary Ogg files are extracted from the user-supplied verified ZIP
in audio_drop/ by running: python tools/import_audio.py

Generated resource paths:
- audio/hmm_menu_seamless.ogg - plays only on the main menu.
- audio/casino_room_tone_seamless.ogg - plays continuously through an autoload.

Their tails/heads have been crossfaded and both Ogg streams are explicitly
configured with loop=true in AudioDirector. The imported binaries are ignored
by Git to avoid storing a duplicate of the same 1.3 MB pack.


## Optional recorded footsteps

The local, user-supplied `Casino_Anomaly_Footsteps.zip` contains 36 prepared WAV clips: 6 each of wood/carpet walk/run and 12 wet carpet walk. It is **not tracked** because the Dan Sfx license grants game use but does not expressly grant standalone asset redistribution.

1. Save the supplied ZIP in `audio_drop/Casino_Anomaly_Footsteps.zip` (or pass its path explicitly).
2. From the repository root run `python tools/import_footsteps.py` (or `python tools/import_footsteps.py --archive "C:/path/Casino_Anomaly_Footsteps.zip"`).
3. Open Godot and let it import the files. Local exports should include the imported WAV resources (export all resources). Public CI without this pack uses synthesized fallback steps.

The existing FOOTSTEP volume control and WORLD reverb bus apply to these recordings. Corridor and Flood cues remain separate; Backrooms always use wet carpet walking. Source credits are in the game Credits panel and ASSET_CREDITS.md.
