# Basic driving

**Player update:** see `player_physics.md` for the dynamic bicycle controller and
new gearing controls. S is now brake only; V selects reverse while nearly stopped.
The original controller description below remains the AI implementation reference.

F5 starts practice in the pit stall, in cockpit view.

- W: accelerate. A/D: left/right steering.
- S: brake to a stop; keep holding to reverse, capped at 20 km/h.
- Releasing W/S coasts down gradually. Steering works while moving, including reverse.
- R: reset the car to its assigned pit box without restarting the session clock.
- 4: following exterior inspection view; 5: cockpit. Other camera controls remain.

From the stall, steer gently right into the adjacent pit travel lane, then straighten.
The limiter caps speed at **80 km/h** in the pit-speed zone, including the pit boxes.
A green line and END 80 sign mark the exit at track-local **X = 195 m**, about 11 m
before Turn 1 begins. Past the line, accelerate freely along the T1/T2 exit lane and
merge on the backstraight. The full exit route is still classified as pit lane, but
it is **not** speed limited. Returning to the speed zone reapplies the cap immediately.

The track's `session.json` defines `pit_speed_zone.limit_kph` and a separate X/Z
polygon. The polygon is intersected with the existing pit-lane region; track and
infield positions outside that region are not limited. `exit_line_x` positions the
visual marker and should match the polygon's downstream edge. This is geographic
detection, so spawning, resetting or reversing into the zone works too. It does not
depend on crossing a trigger in a particular direction.

`PlayerState.is_in_pit_lane` describes the complete pit route.
`PlayerState.is_in_pit_speed_zone` enables the limiter.
`PlayerState.speed_mps` is signed controller speed; dashboard/HUD display its absolute
value converted to km/h. Gear, RPM, fuel and lap telemetry remain placeholders.

The initial controller is `game/vehicle/basic_car.gd`: CharacterBody3D, one box
collider, gravity and floor snapping, steering based on wheelbase, reduced steering
lock at high speed, and basic wall collision. The visible car/cockpit tilt to the
banking while the simple body collider stays upright. It has no suspension, tyre
slip, aerodynamics, gearbox, damage or wheel animation. Defaults: 8 m/s² acceleration,
18 m/s² braking, 1.5 m/s² coasting drag, 280 km/h maximum outside the limiter. These
are prototype tuning values, not claims of realistic Indycar dynamics.

The grounded controller can step over surface lips up to 0.15 m, allowing return
from the grass (0.10 m below the road) onto pit pavement and apron. It checks full-body
clearance above and ahead plus a walkable landing; taller barriers remain blocking.
This approximates tyre clearance for the box collider, not suspension behaviour.
`tools/validate_surface_reentry.gd` covers forward/reverse pit re-entry and apron re-entry.

WASD actions are registered with physical keys in InputMap. Vehicle instances accept
input only when `driving_enabled` is enabled by the practice scene, which also supplies
track data and player state. Mirror cameras and the car inspection view follow motion.
Practice expiry still stops the clock only; session-end handling remains future work.

Checks: `tools/validate_driving.gd` exercises movement, speed cap and release, re-entry,
braking, steering, wall stopping and banked ground contact. `tools/validate_practice.gd`
checks spawning, clock and region state. Run either using Godot `--headless --path .
--script tools/<filename>.gd`.
