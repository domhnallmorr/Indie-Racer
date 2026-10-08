# Cockpit preview — Godot 4.7.2

F5 starts practice in the driver's view in the assigned pit box. WASD now drives
the car; see `docs/driving.md` for limiter behaviour and reset controls.
See `docs/practice.md` for session and spawn configuration.

- **5:** cockpit; **1–4:** existing exterior inspection views.
- **[ / ]:** decrease/increase vertical field of view (45–85°, default 65°).
- **Page Up / Page Down:** adjust local eye height (0.73–0.94 m, default 0.80 m).
  The default is 4 cm lower than the original cockpit. The vehicle's model offset
  is applied separately; these numbers are not height above the road.
- **Home:** reset eye height and field of view. Adjustments are session-only.
- **H:** show/hide the driving status and black box panels for a clear dash view.
  The mirror, spotter and menus remain available. Closing a menu preserves this choice.
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
The interior has a continuous curved painted coaming, tapered carbon-lined tub,
six-sided recessed instrument housing with a sun hood, rubber edge seals, metal
fasteners and a right-hand auxiliary switch panel. Switches and the rotary dial
are visual details. There is no interior steering wheel or driver model.
The left-hand gear lever moves briefly on accepted manual or automatic shifts
and returns to centre. Its shaft and knob share the `GearLeverPivot` node.

The IR-05 dash fit is now authored in the interior model rather than applied with
runtime width/rearward metadata. Camera framing is designed around the default
seat/FOV; extreme settings may crop cockpit edges. The full LCD is verified at
0.76, 0.80 and 0.84 m with the default 65-degree FOV.

The builder authors seamless 512-pixel carbon twill albedo, normal and roughness
maps at a consistent physical scale (2 mm tows). Maps are embedded in the GLB,
packed into the Blend, and extracted alongside the GLB by Godot on import.
Keep the generated `cockpit_CarbonTwill_*.png` files and their import settings with
the model. Static meshes are joined by material; the complete cockpit uses nine
mesh instances plus the live display. Paint follows the player's body colour.

The LCD is drawn by `game/ui/cockpit_dashboard.gd` into a 960×440 viewport and
fitted to the chamfered console aperture. It has segmented speed/gear digits,
a sweeping RPM bar, fuel in litres, current/last/best lap times and session name.
Readouts refresh at 20 Hz using the existing player state and lap-timing node.
Out-laps show dashes until timing is armed; race lap numbers stop at the scheduled
distance. Refuelling status and the remaining service time appear along the bottom.
Unsupported water/oil readings are omitted. Speed remains km/h; this does not
change the physics or session units. See `player_physics.md` for controls and tuning.

The exterior's physical mirrors are hidden from the cockpit camera. A single
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
Inspection sees the external driver; cockpit hides the external driver, wheel,
original lining and placeholder mirrors to prevent overlap with the new interior.

`tools/capture_cockpit.gd` captures actual rendered pit, track, service and seat-height
views under `builds/cockpit_*.png`. The on-track images use deterministic sample
telemetry in a frozen scene. It checks live readout mapping, lap states, accepted
gear shifts, LCD framing, the H toggle/menu return, camera switching and mirror
update states. Run with a graphical renderer, not `--headless`.
