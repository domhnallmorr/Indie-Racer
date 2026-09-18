# Engine audio

Every open-wheel car inherits an `EngineAudio` AudioStreamPlayer3D from the shared
vehicle scene, including the player, reference AI and bicycle AI. The placeholder
V8 uses the existing firing harmonics and crank rumble in a shared mono loop.
Pitch and loudness are smoothed; the loop is synthesized once for the whole field.

The active main camera supplies the listener position and orientation automatically.
Switching between cockpit, exterior, fixed track views and AI follow views therefore
moves the listening point too. Mirror viewports explicitly disable 3D listening.
Cars remain audible behind the camera, pan as they pass, and fade with distance.
The initial mix uses a 20 m reference distance, a 650 m cutoff and a -18 dB ceiling
per car. These are starting values for in-game listening and balancing.

Player and bicycle AI audio use actual engine RPM and throttle, including shift cuts.
Reference AI estimates RPM using road speed, tyre radius and configured gear ratios,
with shift hysteresis; acceleration estimates load. This changes only its sound.
Stopped AI engines idle. A player with driving disabled fades out.

Run `--headless --path . --script tools/validate_engine_audio.gd` with Godot to check
field coverage, both AI models, RPM/load, shifting and camera/listener setup.
For listening, select view 3, orbit/zoom toward passing cars, then compare cockpit
(5) and AI follow (6/7). Nearby cars should dominate and move across the stereo field;
the player engine should fade when the camera is far from the player.
