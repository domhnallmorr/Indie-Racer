# Engine audio

Every open-wheel car inherits an EngineAudio Node3D controller from the shared
vehicle scene. It uses the user-supplied IndycarV8 recordings and the RPM/natural
pitch mappings from IndyV8.sfx, replacing the procedural exhaust/intake/turbo.

## Banks and preparation

game/vehicle/engine_sound_bank.gd contains five cockpit power layers, five cockpit
coast layers, three exterior power layers and three exterior coast layers. Several
layers reuse a recording; they are merged into one voice before equal-power
normalization, avoiding doubled playback through those overlaps. The 11 unique
loop resources are shared across the field.

Pitch is current RPM / natural RPM. Adjacent RPM layers crossfade over the SFX
overlap intervals; the first and final layers hold beyond their donor ranges,
including closed throttle at our 13,800 RPM redline. Throttle blends power/coast
over 15–70% inside and 10–70% outside, as specified by the file. Layer loudness,
RPM and load are smoothed. These are adaptations of the SFX, not an exact emulation
of rFactor's complete sound engine.

Run python tools/prepare_engine_audio.py to rebuild the mono PCM copies in
content/vehicles/open_wheel/audio. The originals are untouched. Preparation removes
DC, applies a 12 ms overlap at the loop join, targets 0.22 RMS and caps peaks at
0.90, with a maximum 4x gain. Keep the supplied .wav.import files: compression,
trimming and normalization must remain disabled. Then reimport in Godot.

## Camera and mix

The active main camera determines the mix. Only a car's own Cockpit.camera selects
its non-positional interior bank. Opponents always remain exterior spatial sources.
Chase, AI follow and TV cameras use exterior banks for every car; transitions
crossfade over 180 ms. Mirror viewports do not listen.

Exterior voices use a 12 m reference distance, 650 m maximum range and distance
filtering. Distance cannot boost a voice beyond its unattenuated blend level.
The last 100 m fades before voices stop. Exterior pitch combines engine RPM with
source/listener radial velocities at 343 m/s sound speed. This single pitch update
avoids render-frame RPM updates overwriting a separate native Doppler adjustment;
native Doppler is disabled on engine voices. Source motion is sampled after physics
drivers, listener motion after camera updates, with 60 ms velocity smoothing and
25 ms pitch smoothing. Interior playback has no Doppler. Camera switches, large
camera cuts and car teleports discard the corresponding velocity history.

EngineAudio.engine_volume_db defaults to -12 dB. The Engines bus has a limiter
with a -1 dB ceiling to handle close full-field peaks. Only audible layers play;
phases advance while culled so resuming does not continually restart the recordings.
An opponent allocates only three unique exterior players; interior players are
created only when that car is viewed from its cockpit.

Player and bicycle AI use physics RPM/throttle, with coast audio during shift cuts.
Reference AI estimates RPM using road speed and configured ratios, with shift
hysteresis and acceleration-based load sampled on physics ticks, so extra render
frames cannot alternate power/coast weights. Running stationary engines idle; stopped
engines and a disabled player fade out and stop all their voices. Engine shutdown
holds the last pitch during its fade rather than plunging to zero pitch.

This pass covers engine banks and camera mixing. Starter one-shots, transmission,
shift clunks, backfire, tyre and road sounds remain for a separate audio pass.

## Verification and audition

Run Godot with --headless --path . --script tools/validate_engine_audio.gd.
It explicitly starts test engines and checks the complete 2,000–15,000 RPM/load
range, shared resources, duplicate layers, both AI types, all camera modes,
high-RPM lift, shift cuts, shutdown/restart, distance culling and re-entry. A 90 m/s
TV drive-by checks approach/departure pitch, moving-listener cancellation, camera
cuts, teleport resets and stable AI load across 30/60/144/240 Hz render updates.

Run --headless --audio-driver Dummy --path . --script tools/capture_engine_audio.gd
to render builds/engine_audition.wav through the actual Godot mixer, without
playing through the speakers. Nominal timeline: 0–10s cockpit idle/acceleration/
lift/shift, 10–20s exterior repeat, 20–24s drive-by, 24–27s close full field, then
shutdown. Audio-driver scheduling can slightly shorten the recording. The tool
reports duration, peak and RMS and rejects silent or clipped output.

In game: 5 selects cockpit, 4 player chase, 6/7 AI follow and T trackside TV.
Compare full throttle with lift-off near redline; adjacent RPM layers should
transition smoothly, and only the viewed car should change to its interior bank.
