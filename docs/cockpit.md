# Cockpit preview — Godot 4.7.2

F5 starts practice in the driver's view in the assigned pit box. WASD now drives
the car; see `docs/driving.md` for limiter behaviour and reset controls.
See `docs/practice.md` for session and spawn configuration.

- **5:** cockpit; **1–4:** existing exterior inspection views.
- **[ / ]:** decrease/increase vertical field of view (45–85°, default 65°).
- **Page Up / Page Down:** adjust eye height (0.77–0.94 m, default 0.84 m).
- **Home:** reset eye height and field of view. Adjustments are session-only.
- Exterior views retain right-drag orbit and wheel zoom.

The separate metric interior source is
`source_art/vehicles/open_wheel/cockpit.blend`; its runtime export is
`content/vehicles/open_wheel/models/cockpit.glb`. Run Blender with
`--background --python tools/build_cockpit.py` to regenerate both (overwrites edits).
The interior includes a recessed instrument panel, cockpit lining, steering wheel,
and mirror housings. Camera framing is designed around the default seat/FOV;
extreme settings may crop cockpit edges. The steering wheel sits low below the dash.

The LCD-style panel is drawn by `game/ui/cockpit_dashboard.gd` into a 640×320
viewport, displayed on the 3D console. Speed is labelled km/h, fuel L, water °C.
Speed, gear and RPM are now live from the player bicycle model. Other engine
readings remain placeholders; see `player_physics.md` for controls and tuning.

Mirrors are horizontally flipped rear camera textures at 384×160 each, sharing
the track world. They update only in cockpit view and omit this displayed car.
Their poses follow the displayed car each frame, including pit-box spawning. Future AI cars
must remain on a mirror-visible layer. This is rear camera rendering, not ray-traced
reflection. Lower mirror resolution/update frequency if full-field performance needs it.

`game/camera/cockpit_view.gd` assembles the interior and instruments only for the
display car in the main scene; the reusable external vehicle scene stays visual-only.
Render layers: track 1, external car 2, interior 3, hidden cockpit driver parts 5.
Inspection sees the external driver; cockpit hides the helmet and placeholder mirrors.

`tools/capture_cockpit.gd` captures an actual rendered Godot frame and checks camera
switching/mirror update states. Run with a graphical renderer, not `--headless`.
