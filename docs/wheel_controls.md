# Steering wheel controls

Connect the wheel and pedals before starting Godot. Press **F10** in practice to open setup. Detected device names appear at the bottom. This uses Godot's joystick input; the device must appear there before calibration can work.

For the Logitech G29 (and other detected wheels):

1. Click **Calibrate steer**, turn the wheel to the desired full-left driving range, and click **Capture**. Centre the wheel and capture again; turn fully right and capture again. Use matching left/right rotation ranges.
2. Click **Calibrate throttle**, move the accelerator so it is detected, release it completely, and capture. Press it fully and capture again.
3. Repeat for the brake. Each pedal is assigned independently, with its own rest and full-travel positions, so inverted axes are supported.
4. Optionally bind shift up/down by clicking their buttons and pressing the desired paddles. Paddle shifts select manual mode; **M** restores automatic shifting.
5. Check the live values: steering reads +1 left, 0 centre, -1 right; pedals read 0 released and 1 pressed. Enable calibrated inputs and close with **F10**.

WASD remains available. Opening setup cuts player throttle and applies the brake; the practice clock and AI continue. Disconnecting a device releases its assigned controls. Calibration is saved in `user://wheel_controls.cfg` and restored using device GUID and name, rather than the temporary device number. Two identical USB devices with identical names/GUIDs cannot currently be distinguished.

Existing steering smoothing, speed-sensitive steering range and stability assists remain active. This first version adds analog inputs and paddles; force feedback and clutch input are not implemented. Steering calibration maps your chosen physical wheel range to the existing speed-sensitive steering range, rather than a fixed steering ratio.

If no devices appear, check that Windows detects the wheel, then restart the game. Hardware compatibility and actual driving feel still need verification with the connected wheel.
