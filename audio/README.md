# Runtime-generated audio files

The binary Ogg files are extracted from the user-supplied verified ZIP
in audio_drop/ by running: python tools/import_audio.py

Generated resource paths:
- audio/hmm_menu_seamless.ogg - plays only on the main menu.
- audio/casino_room_tone_seamless.ogg - plays continuously through an autoload.

Their tails/heads have been crossfaded and both Ogg streams are explicitly
configured with loop=true in AudioDirector. The imported binaries are ignored
by Git to avoid storing a duplicate of the same 1.3 MB pack.
