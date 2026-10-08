# Player physics: model and equations

[Back to the overview](player_physics.md). Checked against
[bicycle_model.gd](../game/vehicle/bicycle_model.gd) and
[player_bicycle.gd](../game/vehicle/player_bicycle.gd) on 6 October 2026.
Equations below describe this implementation, including its approximations.

## Coordinates and state

The body frame uses `u` forward and `v` left, in m/s. Positive yaw rate `r`
turns left, in rad/s. Steering `delta` is in radians internally. The model also
stores front/rear axle angular speeds, engine angular speed, throttle, clutch,
gear and filtered longitudinal/contact-force accelerations. Configuration angles use degrees;
engine configuration uses RPM, converted with `omega = RPM * 2*pi/60`.

Let `L` be wheelbase and `f` the static front weight fraction. The distances from
CG to front and rear axles are `a = L*(1-f)` and `b = L*f`. Stiffness and wheel
inertia describe entire axles, not individual tyres.

`advance()` considers automatic shifts once, then divides the supplied tick into
steps no longer than `min(0.0005, 0.8/clutch_rate)` seconds, where
`clutch_rate = clutch_stiffness * (1/engine_inertia + ratio^2*efficiency/rear_axle_inertia)`.
The ratio includes final drive. This bounds the explicit clutch response for
custom gearing and inertias as well as the baseline; the former 1 ms ceiling
was unstable in first gear. Each `_integrate()` step evaluates the coupled
explicit Euler update once. `integration_steps` counts those force evaluations;
clutch torque extrema and heading change accumulate across the tick.

The more expensive step-doubling solver was withdrawn after testing showed no
handling benefit. It is retained only as an offline reference in
`tools/fixtures/step_doubling_reference.gd`. Severe braking remains sensitive to
timestep refinement; see the investigation in [tuning notes](player_physics_tuning.md).

## Axle slip and tyre forces

The front contact velocity is rotated into the steered tyre frame:

```text
front_long = u*cos(delta) + (v + a*r)*sin(delta)
front_side = (v + a*r)*cos(delta) - u*sin(delta)
alpha_front = atan2(front_side, max(abs(front_long), slip_reference_speed))
alpha_rear  = atan2(v - b*r, max(abs(u), slip_reference_speed))
kappa_front = (omega_front*radius_front - front_long) / max(abs(front_long), slip_reference_speed)
kappa_rear  = (omega_rear*radius_rear - u) / max(abs(u), slip_reference_speed)
```

The reference speed regularises slip near rest. The axle-reference tyre helper uses normal load `Fz`,
cornering stiffness `C`, longitudinal stiffness `K`, and grip multiplier `g`:

```text
load_scale = (Fz/reference_load)^load_stiffness_exponent
raw_force = (K*load_scale*kappa, -C*load_scale*alpha)
peak = Fz*friction_coefficient*g * max(Fz/reference_load, 0.1)^(load_grip_exponent-1)
q = length(raw_force)/peak
envelope = sin(q)                                     # q <= pi/2
envelope = sliding + (1-sliding)*exp(-((q-pi/2)/width)^2) # q > pi/2
force = normalized(raw_force) * peak * envelope
```

For each wheel, evaluate this helper with `Fz = 2*wheel_load`, then halve
its force. This preserves the authored per-axle stiffness/reference load while
resolving each side independently. Left and right still share axle slip angles,
slip ratios and angular speed; there is no differential or individual contact
velocity model yet. Sum the two wheel forces to obtain the axle force used in
body and wheel-speed integration.

`load_grip_exponent` is 0.98: peak force grows sublinearly with load above 10%
of reference load. Below that threshold the friction coefficient is held constant
to avoid divergence near wheel lift. At exponent 1 and equal side loads, summed
wheel forces exactly recover the previous axle tyre curve. The existing 0.85
stiffness exponent is separate from this new peak-force exponent.

Zero load, zero grip or zero demand produces zero tyre force. The grip multiplier combines surface grip
and tyre condition. Acceleration/braking and turning share one force budget:
requesting more longitudinal force leaves less lateral force at saturation.
Small-slip stiffness is preserved, with a smooth peak and gradual fall to
`sliding_grip_fraction` (0.85). `post_peak_falloff` (2.0) controls the width of
that fall in normalized combined demand. The pure lateral peak angle is
`(pi/2)*peak/(C*load_scale)`; peak longitudinal slip follows the same expression
with `K`. This is a provisional symmetric curve, not a measured tyre fit.
Displayed grip usage is delivered force divided by peak force: it can fall below
100% beyond the peak. Per-wheel normalized demand is `q/(pi/2)`; values above 1
identify post-peak sliding even when delivered force has dropped. F5 shows loads,
usage and this sliding state; telemetry records all four corners.

## Axle loads, fuel and banks

Dynamic mass is dry mass plus current fuel mass. Yaw inertia scales as
`authored_inertia * dynamic_mass / dry_mass`; CG location stays fixed.

The adapter projects world gravity onto road-forward, road-left and road-normal
axes. Turning on a bank also contributes normal acceleration, using actual yaw
and velocity, not requested steering:

```text
turn_normal_accel = r * dot((u,v), turn_normal_factors)
support_accel = max(0, normal_gravity + turn_normal_accel)
weight = mass*support_accel                       # grounded only
contact_accel = (front_force_body_x + rear_force_x - rolling_force_x)/mass
transfer = clamp(mass*filtered_contact_accel*cg_height/L, -0.35*weight, 0.35*weight)
front_load = max(0, weight*f + front_downforce - transfer)
rear_load  = max(0, weight*(1-f) + rear_downforce + transfer)
```

`turn_normal_factors` comes from rotating each road-plane basis vector about
world up and projecting that change onto the road normal. On a steady banked
turn this represents the normal component of centripetal acceleration.
Contact-force acceleration is filtered with a step weight `min(1, dt*12)`.
Aerodynamic drag and road gravity act through the CG in this approximation, so
they contribute to deceleration but not directly to the pitch moment. Engine
braking, service braking, traction and rolling resistance act at road level and
do contribute to transfer. Using total deceleration here incorrectly unloads the
rear under high-speed aero drag, even in neutral. This is the CG-drag pitch
equilibrium described in the [Vehicle Body equations](https://www.mathworks.com/help/sdl/ref/vehiclebody.html).
Separate filtered total acceleration remains available for diagnostics.
Left/right loading uses a filtered contact-force roll moment:

```text
lateral_contact_accel = (front_force_body_y + rear_force_y - rolling_force_y)/mass
filtered_lateral += (lateral_contact_accel-filtered_lateral) * (1-exp(-dt/roll_transfer_response_s))
roll_moment = mass * filtered_lateral * cg_height
front_transfer = clamp(roll_moment*front_roll_fraction/front_track, -front_load/2, front_load/2)
rear_transfer = clamp(roll_moment*(1-front_roll_fraction)/rear_track, -rear_load/2, rear_load/2)
FL = front_load/2-front_transfer; FR = front_load/2+front_transfer
RL = rear_load/2-rear_transfer;   RR = rear_load/2+rear_transfer
```

Positive leftward tyre force loads the right tyres. This uses tyre/contact force,
not total acceleration including bank gravity: bank gravity already reduces the
contact force needed to corner. Downforce and longitudinal transfer enter through
the axle totals; aero is assumed centred left/right and applied through the CG.
The 0.12-second roll response is a provisional settling approximation, not a
spring/damper or body-roll solver. It uses the previous substep's filtered force.
Airborne contact clears its history; wheel loads and forces vanish.

The split conserves each axle's load and clips at zero inside-wheel load. Beyond
wheel lift it does not redistribute excess roll moment or simulate rollover.
There is no suspension travel, roll-centre geometry, unsprung mass, camber,
left/right contact sampling, or yaw moment from unequal longitudinal wheel
forces. See [tyre loads and roll balance](tyre_loads.md) for setup and validation.

Fuel mass uses US gallons converted to litres times fuel density. Consumption
uses distance, configured range and a burn factor; it does not integrate engine
power. Race tyre condition similarly follows eligible distance. See
[player_state.gd](../game/vehicle/player_state.gd) and [tyre wear](tyre_wear.md).

## Engine, clutch and brakes

`torque_at()` interpolates torque rows by RPM, then between closed- and
full-throttle torque. Negative closed-throttle values supply engine braking.
Throttle changes at a configured rate. Redline selects closed-throttle torque;
an idle regulator and minimum engine speed prevent normal stalls.

```text
ratio = selected_gear_ratio * final_drive        # negative in reverse; zero in neutral
clutch_torque = clamp((engine_omega - rear_omega*ratio)*clutch_stiffness,
                      -clutch_capacity*engagement, clutch_capacity*engagement)
drive_torque = clutch_torque*ratio*efficiency
engine_omega_change = (engine_torque - clutch_torque)/engine_inertia * dt
```

Clutch engagement ramps with RPM and driven-wheel speed. Neutral, engine-off
state and the shift interval disengage it. Automatic upshifts require both
engine RPM and coupled wheel RPM above threshold and rear slip below 0.20.
Automatic downshifts require engine, coupled wheel and road-speed-equivalent RPM
below the downshift threshold, and a reconnected clutch. Below idle-equivalent
speed the box can return to first without waiting for the launch clutch to engage.
The next ratio must also stay below the automatic upshift threshold, avoiding
immediate hunting with widely spaced custom ratios.

An automatic downshift blips the engine during the open-clutch shift interval.
A 0.04 s response target requests torque from the existing engine curve, bounded
by its closed/full-throttle torque and redline. Engine and axle speeds are never
assigned to force a match. The blip ends before clutch reconnection; normal engine
braking remains. Manual shifts retain their existing clutch and throttle behaviour.
Manual and automatic gear selection share direction-change and over-rev checks.

Tyre reaction torque changes axle angular speed; rear drive torque accelerates
the driven axle. Brake input moves each axle speed toward zero using brake
force, bias, rolling radius and axle inertia. Traction and anti-lock assists can
then directly correct axle speeds. There are no independently driven rear wheels.

## Aero and resistance

Air-relative velocity is body velocity minus projected wind. With its magnitude
`Vair`, coefficient-areas `CdA` and `ClA`, and smoothed tow reduction `t`:

```text
drag = 0.5*density*CdA*Vair^2*(1-t)
downforce = 0.5*density*ClA*Vair^2                # tyre load only while grounded
rolling = rolling_resistance*(front_load + rear_load)
```

Drag opposes air-relative velocity; rolling resistance opposes road-relative
velocity with a low-speed denominator floor of 0.5 m/s. Downforce splits by the
computed front aero fraction. Body and wing settings generate coefficient-areas
in [aero_model.gd](../game/vehicle/aero_model.gd); area must not be multiplied in
again. Tow changes drag only. See [aero](aero.md) and [slipstream](slipstream.md)
for reconstruction assumptions and wake rules.

## Body integration and assists

Rotate front tyre force back into body axes, add rear force and subtract
resistance to obtain `Fx` and `Fy`. Before assistance:

```text
du/dt = Fx/mass + gravity_forward + v*r
dv/dt = Fy/mass + gravity_left - u*r
dr/dt = (a*front_force_body_y - b*rear_force_y)/yaw_inertia
```

Each Euler step retains the previous `u` for the lateral rotating-frame term.
These equations describe the force-driven part; additional handling interventions
are applied within each step:

- `steering_assistance` controls an optional speed-only range and digital response rate.
  Let `s = clamp(speed/steering_reduction_speed_mps, 0, 1)` and
  `help = assistance_strength*steering_assistance`. Effective lock is
  `lerp(steering_lock_deg, high_speed_lock_deg, s*help)`. Normalized input maps
  linearly to that lock. At default help, range is 28 degrees at rest and 4.5
  degrees from 75 m/s (270 km/h) upward. Help off gives 28 degrees at every speed.
  Digital steering rate is `lerp(base_rate, min(base_rate, lock/steering_response_s), help)`.
  Calibrated wheel input bypasses this slew and directly sets the mapped angle
  each substep. Keyboard override and missing/disconnected bindings use digital slew.
  Neither range nor rate uses grip, wings, yaw, bank, throttle or slide direction;
  countersteering uses the same mapping as turn-in. There is no range history.
  Below 75 m/s, the enabled speed help still changes the mapping as speed changes.
- `stability_assistance` controls yaw correction, the excess-yaw clamp and
  exponential sideslip damping. At zero these interventions are absent.
- `traction_control` and `anti_lock_brakes` independently adjust axle angular speeds.
- A stopped-car rule clears tiny residual motion in qualifying low-speed conditions.
- Pit and reverse limits can scale planar velocity directly to a hard cap.

Ground-dependent yaw, sideslip and axle interventions turn off when airborne.
Steering input scaling remains consistent through brief losses of road contact.
Assistance therefore changes the response beyond the tyre-force equations.
All four strengths are multiplied by `assistance_strength`. Defaults retain
steering assistance and ABS at 1, with stability and traction control at 0.
The F10 Controls panel exposes all five strengths for the current session;
telemetry records their values every tick, including mid-session changes.

## Godot integration boundary

`drive_step()` samples road contact, grip, wind and tow; applies session input
rules; and advances the model. It rotates the body about world up, converts model
velocity into world velocity and invokes the shared movement/contact routine.
Airborne vertical motion uses gravity. Resolved contact velocities feed back via
`_receive_contact_velocity()`; a separate obstruction fallback handles restricted
movement. The pit speed zone is checked again after movement for immediate re-entry.

Fuel and tyre distance consumption, telemetry and visual ground alignment follow.
Car contacts use equal-mass horizontal impulses with restitution 0.35. Walls use
restitution 0.25 and friction bounded by 0.12 of normal velocity change. Neither
response adds impact-induced yaw. See [contacts](car_contacts.md) for severity
signals and validation.
