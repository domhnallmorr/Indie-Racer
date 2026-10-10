# Steering wheel controls

Connect the wheel and pedals before starting Godot. Press **F10** in practice to open the Controls screen, which contains keyboard/camera help and wheel setup. Detected device names appear at the bottom. This uses Godot's joystick input; the device must appear there before calibration can work.

The rear differential model is now the only player handling model. It resolves
all four wheel contact velocities and rotational speeds. Older handling choices
and saved `driving_options.cfg` selections are no longer used.

The in-session F10 screen provides **Rear Differential** settings: **Drive locking**,
**Coast locking** and **Preload**, starting at 30% / 10% / 20 Nm. Changes apply
immediately and survive pit resets; each new session restores these defaults.
See [differential controls](rear_differential.md). F11 telemetry identifies the
model as `wheel_contacts_rear_differential_v1`.

For the Logitech G29 (and other detected wheels):

1. Click **Calibrate steer**, turn the wheel to the desired full-left driving range, and click **Capture**. Centre the wheel and capture again; turn fully right and capture again. Use matching left/right rotation ranges.
2. Click **Calibrate throttle**, move the accelerator so it is detected, release it completely, and capture. Press it fully and capture again.
3. Repeat for the brake. Each pedal is assigned independently, with its own rest and full-travel positions, so inverted axes are supported.
4. Optionally bind shift up/down by clicking their buttons and pressing the desired paddles. Paddle shifts select manual mode; **M** restores automatic shifting.
5. Check the live values: steering reads +1 left, 0 centre, -1 right; pedals read 0 released and 1 pressed. Enable calibrated inputs and close with **F10**.

WASD remains available. Opening any race UI screen suspends player driving; the practice clock and AI continue. Disconnecting a device releases its assigned controls. Calibration is saved in `user://wheel_controls.cfg` and restored using device GUID and name, rather than the temporary device number. Two identical USB devices with identical names/GUIDs cannot currently be distinguished.

F10 **Speed steering help** controls steering range. At the default 100%, your calibrated full turn gives 28 degrees of road-wheel angle at rest, reducing smoothly to 4.5 degrees at 270 km/h and above. At 0%, the calibrated range maps to a fixed 28 degrees at every speed; this is much more sensitive at racing speeds. Master strength scales this option. Changes apply for the session.

Wings, tyre grip, banking and yaw do not change the steering mapping. A connected, calibrated steering axis now commands the road-wheel angle directly each tick, including countersteering. It bypasses the keyboard's steering rate limit. Keyboard override, disabled wheel controls and disconnected/missing steering bindings retain the digital rate limit; opening setup clears direct steering. Existing calibration is retained. Stability and traction control default to off; ABS remains on. Force feedback and clutch input are not implemented.

If no devices appear, check that Windows detects the wheel, then restart the game. Hardware compatibility and actual driving feel still need verification with the connected wheel.
