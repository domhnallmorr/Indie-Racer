# Player physics: model and equations

[Back to the overview](player_physics.md). Checked against
[bicycle_model.gd](../game/vehicle/bicycle_model.gd) and
[player_bicycle.gd](../game/vehicle/player_bicycle.gd) on 30 September 2026.
Equations below describe this implementation, including its approximations.

## Coordinates and state

The body frame uses `u` forward and `v` left, in m/s. Positive yaw rate `r`
turns left, in rad/s. Steering `delta` is in radians internally. The model also
stores front/rear axle angular speeds, engine angular speed, throttle, clutch,
gear and filtered longitudinal acceleration. Configuration angles use degrees;
engine configuration uses RPM, converted with `omega = RPM * 2*pi/60`.

Let `L` be wheelbase and `f` the static front weight fraction. The distances from
CG to front and rear axles are `a = L*(1-f)` and `b = L*f`. Stiffness and wheel
inertia describe entire axles, not individual tyres.

`advance()` considers automatic shifts once, then divides the supplied tick into
`ceil(delta_time/0.001)` steps. Each step is at most 1 ms. Forces, axle speeds,
body velocity and yaw are updated explicitly in `_integrate()`; heading change
accumulates across these steps. This is not an implicit suspension solver.

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

The reference speed regularises slip near rest. With axle normal load `Fz`,
cornering stiffness `C`, longitudinal stiffness `K`, and grip multiplier `g`:

```text
load_scale = (Fz/reference_load)^load_stiffness_exponent
raw_force = (K*load_scale*kappa, -C*load_scale*alpha)
force = raw_force limited to length (Fz*friction_coefficient*g)
```

Zero load produces zero tyre force. The grip multiplier combines surface grip
and tyre condition. Acceleration/braking and turning share one force budget:
requesting more longitudinal force leaves less lateral force at saturation.
There is no separate post-peak tyre curve. Displayed grip usage is the length of
the capped force divided by available grip, not the uncapped demand.

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
transfer = clamp(mass*filtered_accel*cg_height/L, -0.35*weight, 0.35*weight)
front_load = max(0, weight*f + front_downforce - transfer)
rear_load  = max(0, weight*(1-f) + rear_downforce + transfer)
```

`turn_normal_factors` comes from rotating each road-plane basis vector about
world up and projecting that change onto the road normal. On a steady banked
turn this represents the normal component of centripetal acceleration.
Longitudinal acceleration is filtered with a step weight `min(1, dt*12)`.
There is no left/right load resolution or suspension travel.

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

The implementation updates these sequentially and retains the previous `u` for
the lateral rotating-frame term. These equations describe the force-driven part;
additional handling interventions are applied afterward:

- Speed and estimated grip restrict steering lock; steering moves at a limited rate.
- Yaw assistance approaches a grip-limited steering target and limits excess yaw error.
- Sideslip damping exponentially reduces lateral velocity.
- Traction/braking assistance adjusts axle angular speeds directly.
- A stopped-car rule clears tiny residual motion in qualifying low-speed conditions.
- Pit and reverse limits can scale planar velocity directly to a hard cap.

Ground-dependent yaw, sideslip and axle interventions turn off when airborne.
Steering input scaling remains consistent through brief losses of road contact.
Assistance therefore changes the response beyond the tyre-force equations.

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
