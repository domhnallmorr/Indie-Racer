# Car contacts and straight-line pace — 18 September

The reference AI previously scaled the entire recorded speed trace by its lap
rating and then added an 8% passing boost. The fastest roster entry could request
346.4 km/h against a 308.3 km/h peak in the recorded player lap.

Passing now adds 2%. Above 85% of the reference peak, lap-rating speed scaling
smoothly narrows to +/-2%, reaching that range at 98% of the peak. Corner pace
still uses the original rating. Current maximum targets are 314.5 km/h in clean
air and 320.8 km/h while passing. The original lap ratings are retained, so actual
lap times may change. Acceleration and braking limits still apply.

Traffic guarding now uses stopping distance as well as the short-gap controller,
with a 0.25-second closing-distance allowance. It observes rivals out to 340 m
and considers threats within 3.5 seconds of travel. A newly occupied swept path
halts an ongoing lane transition, including its steering preview. Cars alongside
also reserve 3.2 m between centres when the authored racing and passing grooves
converge through a corner.

All car controllers share a temporary equal-mass contact response. A horizontal
impulse uses relative closing speed and restitution 0.35; both cars receive the
response, once per pair per physics tick. Reference AI retain a short lateral
drift, damped at 4 m/s², while player contacts feed the existing bicycle dynamics.
Glancing contact preserves forward momentum instead of treating the other car
as a stationary wall. Solid barriers use the rebound response described below.
This is a forgiving prototype response, without damage or impact-induced spin.

## Wall response and future damage

Wall contacts retain tangential motion, return 25% of the incoming normal speed,
and apply friction limited to 12% of the normal velocity change. The resolved
velocity feeds directly back into player and AI dynamics; distance travelled in
the collision frame must not overwrite it. Separating contacts get no impulse.
Duplicate coplanar contacts in one tick are resolved once. Floor/ceiling contacts
do not generate wall impacts. This remains a horizontal prototype without spin.

The outer wall, inner wall and pit separator had inward-facing mesh triangles.
Their runtime mesh, Blender source and generator now use outward-facing walls,
so cars collide with the near face rather than entering the wall volume.

Cars emit `wall_impact(impact: Dictionary)` for closing speeds of at least 1 m/s.
The dictionary contains world-space `position` and `normal`, `collider_id`,
`physics_frame`, `closing_speed_mps`, `delta_velocity_mps`, `normal_impulse_ns`,
and `normal_energy_j`. Impulse and energy use configured mass plus current fuel.
Normal energy is incoming energy into the wall (0.5 × mass × closing speed²),
not a calibrated damage amount or total energy dissipated. Each resolved inward
impact can emit; sustained throttle can cause subsequent small impacts.

`last_wall_impact` retains the latest event until reset. `wall_impact_this_step`
contains the strongest event this tick, or an empty dictionary. The physics
panel shows the last closing speed and energy; F11 telemetry appends four wall
impact columns, with zeroes on ticks without an event. Future damage can connect
to the signal without depending on telemetry or introducing damage thresholds now.

`tools/validate_wall_contacts.gd` exercises glancing, head-on, reverse, gentle
and separating contacts, subsequent separation, severity data, and real straight
and banked outer-wall geometry.

Validation scripts:

- `tools/validate_car_contacts.gd`: physical rear impacts and sideswipes for
  AI/AI and both player/AI directions, separation, retained speed, and barriers.
- `tools/validate_ai_safety.gd`: full-roster speed targets, stopped traffic,
  fast closing, sudden leader braking, and blocked steering preview.
- `tools/validate_icr2_field.gd`: five-minute 15-car practice, speed peak,
  completed passes, contacts, track bounds, pit limiting and circulation.
- Existing player-physics, racecraft-rules, passing and green-launch checks
  cover shared handling and normal racing behaviour.

The seed-1234 five-minute practice comparison reduced recorded car-contact ticks
from 93 to zero, with ten completed passes, 320.8 km/h peak speed, no pit-limit
violations, and maximum road-centre offset 7.17 m. Every AI completed at least
seven laps. The two-car pit-departure regression measured 21.303/22.713-second
best laps, zero contact ticks and successful limiter/merge checks. These are
repeatable fixture results, not a guarantee against arbitrary player impacts.
