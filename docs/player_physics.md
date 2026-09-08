# Player bicycle physics — Godot 4.7.2

The player now uses a dynamic bicycle model with two axle tyres and rear-wheel
drive. The two AI cars deliberately retain `basic_car.gd` and their existing pace.

**Forgiving keyboard setup:** stability control, sideslip damping, traction control
and anti-lock braking are now enabled by default in `physics/assists.cfg`.
Steering builds over approximately 0.3 seconds and maximum angle is reduced to suit
speed and available grip. These are deliberately strong handling assists, not a
claim of authentic 1995 electronics. Set `assistance_strength=0` to restore the
unassisted dynamics; intermediate values reduce assistance. The AI is unchanged.
The external vehicle scene stays the AI version; `scenes/player_vehicle.tscn`
overrides its script for the player. No AI driving parameters were retuned.

## Controls

| Key | Action |
| --- | --- |
| W | Throttle, including when reverse is selected |
| S | Brake only; holding it no longer selects reverse |
| A / D | Steer left/right, with progressive input and speed-dependent lock |
| Q / E | Shift down/up; selects manual shifting mode |
| M | Toggle automatic/manual forward shifting |
| V | Select reverse / return to first, only below 0.5 m/s |
| N | Neutral |
| R | Reset to assigned pit box; clears velocities, yaw, wheel speeds and clutch, selects first |
| 8 | Show/hide physics debug panel |
| 9 | Existing practice timing panel |

Starts in first with automatic shifting enabled. Automatic clutch assistance is
always enabled; there is no clutch pedal or engine-stall simulation. Q/E can step
through R, N, 1–6. Shifts have a torque interruption and cannot be stacked during
the shift interval. Downshifts that would over-rev the engine are rejected, and
reverse cannot engage while moving faster than the direction-change threshold.
Neutral requires E to select first again. Reverse has a 25 km/h assistance cap.
Reset preserves the chosen automatic/manual preference and previously completed laps.

## Editable physics files

All are in `content/vehicles/open_wheel/physics/`, use Godot ConfigFile syntax with
`[meta] schema_version=1`, and load at startup. Restart the session after editing.
Missing fields, nonfinite/negative values, zero divisors, bad ratios and invalid RPM
ordering are rejected with an Output error; player driving does not silently fall
back to a different parameter set. The files are inputs, not generated outputs.

| File | Main parameters / initial values |
| --- | --- |
| `chassis.cfg` | 700 kg, 2.82 m wheelbase, 43% static front weight, 0.32 m CG height, 1000 kg·m² yaw inertia, 18,000 N total brake-force setting and 57% front brake bias |
| `tires.cfg` | 0.315/0.34 m front/rear rolling radii; axle cornering/longitudinal stiffness; μ=1.65; rolling resistance; wheel inertias; grass grip multiplier |
| `engine.cfg` | User-supplied RPM/closed-throttle/full-throttle torque curve; 2500 RPM idle target, 13,800 RPM redline; engine inertia, throttle response and idle regulation |
| `gearbox.cfg` | Six forward ratios, reverse, final drive, efficiency, shift time, auto shift thresholds and assisted clutch parameters |
| `aero.cfg` | Air density, drag coefficient×area 0.80 m², downforce coefficient×area 3.6 m², 43% front aero balance |
| `assists.cfg` | Assistance strength, steering response, cornering margin, yaw/sideslip control, traction and braking slip limits |

Units are kg, metres, seconds, newtons, Nm and kg·m². Engine speed uses RPM;
configuration steering angles use degrees. Cornering stiffness is N/radian **per
axle**, longitudinal stiffness is N per unit slip ratio, and the wheel inertias
are combined axle values. The front weight fraction sets the longitudinal CG:
CG-to-rear distance = wheelbase × front fraction. Aero inputs already include area;
do not multiply by a reference area again. Values are initial game tuning, not a
validated reconstruction of a specific 1995 chassis or tyre.

The torque curve preserves the provided numerical values, including negative
closed-throttle torque. 411 Nm at 13,000 RPM corresponds to about 559.5 kW. The
model interpolates between rows and between closed and open throttle; a fuel cut
acts at redline. No separate boost simulation is layered on top of that curve.

## Implemented model

`game/vehicle/bicycle_model.gd` integrates longitudinal speed, lateral speed, yaw
rate, front/rear axle angular speeds, engine angular speed and steering. Force and
yaw equations use the standard single-track structure described in the
[MathWorks vehicle-body reference](https://www.mathworks.com/help/vdynblks/ref/vehiclebody3dof.html).
Tyres use our simple saturating combined-force implementation, not a Magic Formula fit.

- Front/rear slip angles generate lateral force through axle stiffness.
- Wheel slip ratios generate longitudinal force; driven rear wheels can spin and
  braking can lock the tyres with assists disabled. Default traction and braking
  assistance limit wheelspin/lock-up; they directly correct axle speed in this prototype.
- Each axle's combined longitudinal/lateral force is limited by μ × normal load.
  Braking or acceleration therefore consumes grip otherwise available for turning.
- Static weight, approximate filtered longitudinal load transfer and aerodynamic
  downforce determine front/rear loads. No lateral left/right load transfer yet.
- Engine torque passes through an assisted friction clutch, gear ratio, final drive
  and drivetrain efficiency. Engine inertia and wheel inertia participate in the
  integration. The idle helper prevents stalls rather than modelling a starter.
- Drag and downforce scale with speed squared. Drag opposes planar velocity, and
  downforce increases tyre normal loads. No artificial forward top-speed cap outside
  the pit zone: the gearing/redline and power/resistance determine speed.
- Force calculations use the current road plane, including gravity along a bank and
  the gravity component normal to it. Grass has reduced grip.
- Physics integration uses substeps no longer than 1 ms for low-speed tyre stability.
  Slip regularisation and a tiny stopped-car settling rule avoid standstill jitter.

`player_bicycle.gd` couples this model to Godot's existing CharacterBody3D collision
and ground support. It preserves the 0.15 m surface-step fix, visually tilts the
car/cockpit to the road, and reconciles velocity after a wall impact. The collider
is still upright and simplified. This is not independent wheel suspension or full
3D rigid-body dynamics; airborne motion has gravity but no roll/pitch dynamics.
Car-to-car contact does not yet exchange realistic mass-based impulses.

The pit controller reduces throttle approaching 80 km/h and retains a hard safety
cap, including on re-entry. It can settle slightly below 80. The cap releases at
the existing END 80 line before T1; the rest of the exit lane stays unlimited.

## Tuning and feedback

Cockpit speed, RPM bar and gear are live. Fuel, water and the separate cockpit
lap/time fields remain placeholders; 9 still gives live session timing.
Debug key 8 shows longitudinal/lateral speeds, yaw, steering angle, axle slip angles
and ratios, grip usage, loads, aero forces and clutch engagement.

The default setup is designed to tolerate full keyboard input without snap spins.
Taking a corner too fast can still make the car run wide; braking for the turn helps.
Yaw assistance follows steering intent and damps excess rotation and lateral sliding.
It deliberately adds stability outside the physical tyre-force calculation.
Tune grip and cornering stiffness first, then balance and aero. Change one parameter
group at a time. Increasing yaw inertia slows rotation; more forward brake bias
favours front locking; changing front/rear grip or aero balance changes handling.

The initial straight-line test reaches approximately 317 km/h in sixth. That is a
test of this parameter set, not a measured target for Milwaukee. Existing AI race
pace is intentionally unchanged and will not yet match the player's capabilities.

## Verification and remaining work

- `tools/validate_bicycle.gd`: torque interpolation, all six gears, braking/locking,
  neutral, reverse, downshift protection, redline, pit cap/release, left/right yaw,
  combined grip, aero, bank gravity, airborne traction, 60/120 Hz agreement and invalid configuration.
- `tools/validate_player_physics.gd`: actual-track launch, ground support, limiter,
  walls, grass re-entry in both directions, banking and reset state.
- `tools/validate_surface_reentry.gd` and `tools/validate_practice.gd`: retained
  regressions, now using track-local test positions so saved track translations work.
- `tools/capture_physics.gd`: actual rendered cockpit and debug panel.
- `tools/validate_stability.gd`: abrupt keyboard direction changes under throttle,
  braking and steering release at 72, 144 and 216 km/h initial speeds. Default
  assistance kept peak sideslip below 2.5° in these synthetic tests.

Next work is subjective handling tuning and stronger skid/limit feedback, followed
by adapting the AI controller. Suspension, tyre temperatures/wear, fuel consumption,
damage, engine audio, wheel animation, and advanced differential behaviour remain
outside this version.
