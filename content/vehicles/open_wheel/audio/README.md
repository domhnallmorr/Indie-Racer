# Sampled V8 engine loops

Derived from the user-supplied `IndycarV8` folder and its `IndyV8.sfx` mappings.
Original recordings remain in that folder; these are prepared runtime copies.

Rebuild with `python tools/prepare_engine_audio.py`, then let Godot reimport them.
The script reads the engine sample references from the SFX, downmixes to mono,
removes DC, overlaps the loop join by 12 ms and matches RMS level with peak
headroom. It does not synthesize or replace the engine character.

Keep the accompanying WAV import settings: no trimming or normalization and
**compression disabled**. `engine_sound_bank.gd` sets full-length PCM loop bounds
and caches one resource per sample for all cars. Configuration and validation are
documented in `docs/audio.md`.

This first pass uses 11 engine recordings only. The source folder's transmission,
starter, shift, tyre, surface and impact recordings are not wired into gameplay yet.
