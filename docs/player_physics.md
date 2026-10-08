# Player car physics

Implementation overview, checked against the working tree on 4 October 2026.
This describes the current prototype; numerical tuning is not a validated
reconstruction of a particular IndyCar chassis, tyre or engine.

## Start here

The player uses a custom **dynamic bicycle (single-track) model**: front/rear axle kinematics
with left/right tyre loads and force evaluation. Engine torque,
tyre slip, braking and aerodynamic forces determine motion along the road plane.
Godot's `CharacterBody3D` supplies movement, ground contact and collision queries.
The car is not driven by Godot's built-in `VehicleBody3D` wheel simulation.

Read this overview first, then use:

- [Model and equations](player_physics_model.md) for the simulation state, forces and update order.
- [Tuning reference](player_physics_tuning.md) for configuration, units and handling effects.
- [Aero](aero.md), [gearing](gearing.md), [slipstream](slipstream.md) and
  [tyre wear](tyre_wear.md) for detailed subsystem behaviour.
- [Car and wall contacts](car_contacts.md), [wheel controls](wheel_controls.md),
  [wheel visuals](wheel_visuals.md) and [audio](audio.md) for related systems.

## How a driving tick works

```mermaid
flowchart TD
    A[Driver inputs] --> B[Session rules: caution, pit stop, limiter]
    C[Fuel, tyre condition, road contact, wind and tow] --> D[Player physics adapter]
    B --> D
    D --> E[Bicycle model: clutch-bounded Euler steps]
    E --> F[Engine and clutch, axle slip, tyre forces, aero and assists]
    F --> G[Road-plane speed and yaw]
    G --> H[Godot movement and contact response]
    H --> I[Reconcile velocity, enforce pit cap, consume fuel and tyres]
    I --> J[Telemetry and visual grounding]
    H --> D
```

The internal substeps resolve the tyre/drivetrain model. Collision movement and
road sampling happen at the outer driving tick, not once per model substep.

## Code map

| Responsibility | Source |
| --- | --- |
| Player scene and controller selection | [player_vehicle.tscn](../content/vehicles/open_wheel/scenes/player_vehicle.tscn) |
| Inputs, road-plane conversion and simulation integration | [player_bicycle.gd](../game/vehicle/player_bicycle.gd), especially `drive_step()` |
| Force calculation and numerical integration | [bicycle_model.gd](../game/vehicle/bicycle_model.gd), `advance()`, `_integrate()`, `_tyre()` |
| Configuration loading and validation | [physics_config.gd](../game/vehicle/physics_config.gd) |
| Movement, ground support and contact response | [basic_car.gd](../game/vehicle/basic_car.gd) |
| Fuel, tyre condition and pit service | [player_state.gd](../game/vehicle/player_state.gd) |
| Wing/body coefficient calculation | [aero_model.gd](../game/vehicle/aero_model.gd) |
| Wake sampling | [slipstream.gd](../game/vehicle/slipstream.gd) |
| Recorded physics data | [telemetry.gd](../game/vehicle/telemetry.gd) |

AI controllers vary: bicycle-physics AI and reference-speed AI have separate
behaviour. See [AI physics](ai_physics.md) and [ICR2 method](icr2_method.md).
Do not assume a player tuning change affects every opponent in the same way.

## What is modelled

| System | Current behaviour |
| --- | --- |
| Tyres | Slip angle and slip ratio share a smooth combined-force envelope, with a peak and gradual fall to sliding grip. Peak grip is load-sensitive; surface and tyre condition scale grip. |
| Weight and banking | Dry mass plus fuel; longitudinal and lateral load transfer, four tyre loads, adjustable roll balance, road gravity and turning load on banks. |
| Powertrain | Torque curve, engine and axle inertia, assisted friction clutch, six forward gears, neutral and reverse; rear-wheel drive. |
| Braking | Front/rear brake bias and axle brake torque; lock-up is possible with assists disabled. |
| Aero | Body package and wing angles determine drag, downforce and aero balance. Forces use air-relative speed. |
| Slipstream | A smoothed wake reduces drag by up to 9%; it does not directly reduce downforce. |
| Fuel | Distance-based consumption changes vehicle mass and scaled yaw inertia. Empty fuel removes throttle input. |
| Tyre wear | One condition value for the whole car, consumed during eligible race running; grip falls to 92% at fully worn condition. |
| Contacts | Horizontal car impulses and wall rebound/friction feed velocity back into the player model. |
| Assists | Steering restriction, yaw correction, sideslip damping and direct axle-speed intervention for traction/braking. |

Default steering assistance and ABS remain enabled; stability control and traction
control are disabled so tyre forces can produce oversteer. F10 exposes these four
strengths separately plus a master strength, for the current session. Setting
`assistance_strength=0` disables these handling interventions, but automatic clutch
assistance, base steering limits, pit/reverse caps and session rules still apply.

## Controls and diagnostics

| Input | Action |
| --- | --- |
| W / S | Throttle / brake; W also powers reverse |
| A / D | Progressive steering |
| Q / E | Shift down/up and select manual mode |
| M | Toggle automatic forward shifting |
| V | Select reverse / first, subject to the direction-change speed check |
| N | Select neutral; E returns from neutral to first |
| R | Reset to the assigned pit box |
| F5 | Live four-tyre loads, grip usage and sliding state |
| F10 | Controls, including independent driving assists |
| 8 | Physics diagnostics |
| F11 | Stop/resume player telemetry |

The player starts in first with automatic shifting. Shifts interrupt drive and
cannot stack during the shift interval; predicted over-rev shifts are rejected.
Wheel mapping is covered in [wheel controls](wheel_controls.md).

Player telemetry starts when a driving session loads and writes CSV plus setup
metadata under `user://telemetry`. Compare actual recorded settings: saved track
setups can override the authored wing and gear defaults. The diagnostics panel
shows slip, grip usage, loads, aero, tow and wall-impact information.

## Validation

These are existing checks to run after relevant changes, not a claim that they
passed on the date of this documentation update. From the project root, use your
Godot executable (replace `godot` if it is not on PATH):

```powershell
godot --headless --path . --script res://tools/validate_bicycle.gd
godot --headless --path . --script res://tools/validate_player_physics.gd
```

| Change | Relevant checks in `tools/` |
| --- | --- |
| Core forces, gears or integration | [validate_bicycle.gd](../tools/validate_bicycle.gd): includes combined grip, airborne traction and 60/120 Hz agreement |
| Numerical accuracy and recovery | [validate_integration_accuracy.gd](../tools/validate_integration_accuracy.gd): offline step-doubling experiment only (not production): nine full replay traces, independent fine Euler reference and bounded stops; [compare_axle_recovery.gd](../tools/compare_axle_recovery.gd): mirrored controlled catches and late-correction stress cases |
| Clutch integration and wheel handling | [validate_driveline.gd](../tools/validate_driveline.gd): torque stability and 60/120/240 Hz convergence against 4000 Hz; [validate_surfers_handling.gd](../tools/validate_surfers_handling.gd): recorded wheel inputs at 57% front brake bias |
| Track integration or ground support | [validate_player_physics.gd](../tools/validate_player_physics.gd), [validate_surface_reentry.gd](../tools/validate_surface_reentry.gd) |
| Four tyre loads and setup | [validate_tyre_loads.gd](../tools/validate_tyre_loads.gd), [validate_roll_setup.gd](../tools/validate_roll_setup.gd); [model and setup notes](tyre_loads.md) |
| Steering input mapping | [validate_steering.gd](../tools/validate_steering.gd) (speed-only/direct travel, independence from grip/wing/yaw, lift at 60/120 Hz) |
| Handling assistance and oversteer | [validate_oversteer.gd](../tools/validate_oversteer.gd), [validate_stability.gd](../tools/validate_stability.gd) (fully assisted profile) |
| Experimental tyre falloff comparison | [compare_tyre_falloff.gd](../tools/compare_tyre_falloff.gd): widths 2/3/4, recent collision-free Surfers inputs, controlled recovery, force limits and numerical sensitivity; does not change defaults |
| Front/rear force balance diagnosis | [investigate_force_balance.gd](../tools/investigate_force_balance.gd): axle forces and yaw moments, isolated diagnostic counterfactuals and severe-braking integration refinement; does not change defaults |
| Lift-off and pitch load transfer | [validate_lift_off.gd](../tools/validate_lift_off.gd): force isolation, recorded Texas input/road replay, setup balance and 60/120 Hz agreement |
| Solo practice session | [validate_private_testing.gd](../tools/validate_private_testing.gd) (all four tracks) |
| Banking | [validate_texas_banking.gd](../tools/validate_texas_banking.gd), [validate_texas_surface_contacts.gd](../tools/validate_texas_surface_contacts.gd) |
| Shifting | [validate_gear_shifts.gd](../tools/validate_gear_shifts.gd): acceleration, automatic downshift timing/rev matching, stopped recovery and Surfers telemetry replay at 60/120 Hz |
| Fuel or wear | [validate_fuel.gd](../tools/validate_fuel.gd), [validate_tyre_wear.gd](../tools/validate_tyre_wear.gd) |
| Tow | [validate_slipstream.gd](../tools/validate_slipstream.gd) |
| Collisions | [validate_car_contacts.gd](../tools/validate_car_contacts.gd), [validate_wall_contacts.gd](../tools/validate_wall_contacts.gd) |
| Recorded data | [validate_telemetry.gd](../tools/validate_telemetry.gd) |

For handling comparisons, hold track, fuel, tyre condition, wings, gearing, input
method and assists constant. Record clean-air runs separately from towing. Keep
measured speed/lap results with those conditions and the code revision rather
than treating an old test's top speed as a permanent specification.

## Current limitations

There is no independent four-wheel suspension, lateral left/right load transfer,
roll/pitch dynamics, detailed differential, tyre temperature or compound model.
Tyre forces use a simple smooth combined-slip curve, not a calibrated Magic Formula
fit. Tyre wear and fuel burn are distance models rather than thermal/combustion
simulations. The idle helper prevents normal stalls; there is no clutch pedal.

Ground alignment is partly visual; the collider stays upright. Airborne motion
has gravity but no full rigid-body attitude simulation. Car contacts use an
equal-mass approximation, and impacts do not generate physical spin or structural
damage. Wall severity events provide inputs for future damage work.

## Keeping this guide current

Update the relevant chapter when changing a model equation, parameter meaning,
setup override or assistance rule. Keep subsystem detail in its linked document.
Record evidence separately from intended behaviour and provisional tuning.
