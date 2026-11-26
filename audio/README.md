# Runtime-generated audio files

The binary Ogg files are extracted from the user-supplied verified ZIP
in audio_drop/ by running: python tools/import_audio.py

Generated resource paths:
- audio/hmm_menu_seamless.ogg - plays only on the main menu.
- audio/casino_room_tone_seamless.ogg - plays continuously through an autoload.

Their tails/heads have been crossfaded and both Ogg streams are explicitly
configured with loop=true in AudioDirector. The imported binaries are ignored
by Git to avoid storing a duplicate of the same 1.3 MB pack.

## Recorded footsteps

The 36 prepared 48 kHz mono WAV clips belong directly in the project under
`audio/footsteps/` (wood_walk, wood_run, carpet_walk, carpet_run: six each;
wet_carpet_walk: twelve). They are ordinary game resources, not a separate
download or runtime extraction dependency. Once committed, a regular pull and
Godot's normal import process are sufficient. The Windows export preset uses
all resources, so the clips are included in development and release builds.

For the one-time asset commit, apply the supplied binary Git patch from the
repository root, then commit the staged files. No Python importer is required.
The original source ZIP is redundant and should not be committed.

The existing FOOTSTEP volume control and WORLD reverb bus apply. Corridor and
Flood cues remain separate; Backrooms always use wet carpet walking. Source
credits are in the game Credits panel, ASSET_CREDITS.md and the asset directory.
Synthesized fallback steps remain available for checkouts lacking the WAVs.
