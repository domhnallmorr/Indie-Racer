# Cockpit preview — Godot 4.7.2

F5 starts practice in the driver's view in the assigned pit box. WASD now drives
the car; see `docs/driving.md` for limiter behaviour and reset controls.
See `docs/practice.md` for session and spawn configuration.

- **5:** cockpit; **1–4:** existing exterior inspection views.
- **[ / ]:** decrease/increase vertical field of view (45–85°, default 65°).
- **Page Up / Page Down:** adjust eye height (0.77–0.94 m, default 0.84 m).
- **Home:** reset eye height and field of view. Adjustments are session-only.
- Exterior views retain right-drag orbit and wheel zoom.

Practice and qualifying pit boxes have a physical monitor in front of the cockpit.
Press **Enter** or click its screen to open a readable close-up. Use mouse,
arrows/Tab and Enter to select **Edit Car Setup**, **Return to Cockpit**, or
**Go to Track**. Edit Car Setup opens a submenu with **Fuel Load** and **Wings**.
Fuel changes apply immediately; Wings contains the body package and wing angles.
**Escape** returns from an editor to the setup submenu, then the main menu, then
the cockpit. Wing setup changes
require Apply and are saved per track; leaving the editor without applying discards
edits. Setup is no longer in F12 and can only be applied while parked in a practice
or qualifying box. The monitor clears before departure and returns on arrival.
Race stops retain LCD refuelling progress and automatic release. Tyre selection
is not implemented.

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

The cockpit's two physical mirror housings and displays are hidden. A single
wide virtual mirror sits at the top centre of the screen in a black frame.
It uses a horizontally flipped 960×180 rear camera texture with a 100° horizontal
field of view, sharing the track world. It appears and updates only in cockpit
view and omits the player's car. Its pose follows the car each frame, including
pit-box spawning, independently of the driver's seat/FOV settings. Future AI cars
must remain on a mirror-visible layer. This is rear camera rendering, not ray-traced
reflection. Lower mirror resolution/update frequency if full-field performance needs it.

`game/camera/cockpit_view.gd` assembles the interior and instruments only for the
display car in the main scene; the reusable external vehicle scene stays visual-only.
Render layers: track 1, external car 2, interior 3, hidden cockpit driver parts 5.
Inspection sees the external driver; cockpit hides the helmet and placeholder mirrors.

`tools/capture_cockpit.gd` captures an actual rendered Godot frame and checks camera
switching/mirror update states. Run with a graphical renderer, not `--headless`.
