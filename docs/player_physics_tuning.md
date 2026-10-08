# Player physics: tuning reference

[Back to the overview](player_physics.md). Authored settings checked on
4 October 2026. These are prototype defaults, not measured vehicle data.

## Where settings come from

The six [physics CFG files](../content/vehicles/open_wheel/physics) use Godot
ConfigFile syntax and `[meta] schema_version=1`. The player loads either this
directory or supplied component paths at startup. Restart the driving session
after editing these files. [physics_config.gd](../game/vehicle/physics_config.gd)
rejects missing/invalid required data and stops player physics on failure.

At runtime, track-specific saved wings/body package and gearing can override the
authored defaults. Texas first applies a 3.40 final-drive baseline; a valid saved
setup takes precedence. Setup files live at `user://aero_setups.cfg` and
`user://gearing_setups.cfg`. Adjust them through the practice/qualifying pit monitor.
Fuel mass and tyre condition also change effective behaviour while driving.

## Chassis and fuel

Source: [chassis.cfg](../content/vehicles/open_wheel/physics/chassis.cfg).

| Setting | Authored value | Meaning and tuning effect |
| --- | --- | --- |
| `mass_kg` | 700 kg | Dry mass; fuel is added. More mass changes acceleration and axle loads. |
| `wheelbase_m` | 2.82 m | Axle spacing; changes yaw moment arms and steering geometry. |
| `front_weight_fraction` | 0.43 | Static front load share and longitudinal CG location. |
| `cg_height_m` | 0.32 m | Higher values increase longitudinal and lateral load transfer. |
| `front_track_m`, `rear_track_m` | 1.65 m, 1.60 m | Provisional track widths; wider track reduces lateral load transfer for a given roll moment. |
| `front_roll_stiffness_fraction` | 0.50 | Front share of roll moment; editable 35–65% in the pit monitor and saved per track. |
| `roll_transfer_response_s` | 0.12 s | Settling time constant for tyre-force-derived lateral load transfer. |
| `yaw_inertia_kgm2` | 1000 kg m² | Dry reference inertia; higher values slow force-driven yaw response. |
| `brake_force_n`, `front_brake_bias` | 18000 N, 0.57 | Total brake setting and front fraction; more forward bias shifts braking demand to the front. |
| `steering_lock_deg`, `high_speed_lock_deg` | 28°, 4.5° | Physical lock and optional high-speed lock; speed steering help blends between them. |
| `steering_reduction_speed_mps` | 75 m/s | Speed at which 100% speed steering help reaches its fixed high-speed range. |
| `steering_rate_deg_s` | 35°/s | Maximum base digital steering rate; calibrated wheel input bypasses slew. |
| `surface_step_m` | 0.15 m | Ground-support step allowance, not suspension travel. |
| `fuel_capacity_gal`, `fuel_density_kg_l` | 35 US gal, 0.792 kg/L | Capacity and mass conversion; session capacity overrides may reduce capacity. |
| `fuel_range_laps`, `fuel_reference_lap_m` | 60, 1609.344 m | Reference distance used to calculate fuel burn, independent of current track lap length. |

## Tyres

Source: [tires.cfg](../content/vehicles/open_wheel/physics/tires.cfg).

| Setting | Authored value | Meaning and tuning effect |
| --- | --- | --- |
| `front_radius_m`, `rear_radius_m` | 0.315, 0.34 m | Slip/torque conversion; rear radius also changes speed per engine RPM. |
| `front_cornering_stiffness_n_rad`, `rear_cornering_stiffness_n_rad` | 90000, 110000 N/rad | Per-axle lateral response before saturation; higher stiffness reaches a given force at less slip angle. |
| `longitudinal_stiffness_n` | 90000 N per unit slip | Longitudinal force response before saturation. |
| `reference_load_n`, `load_stiffness_exponent` | 3500 N, 0.85 | Reference and exponent for load-dependent stiffness. |
| `friction_coefficient` | 1.65 | Friction coefficient at reference load. |
| `load_grip_exponent` | 0.98 | Sublinear peak force versus load; 1 disables peak load sensitivity. |
| `sliding_grip_fraction` | 0.85 | Force retained at large combined slip, relative to peak. |
| `post_peak_falloff` | 2.0 | Falloff width in normalized force demand; larger values soften breakaway. |
| `grass_grip_multiplier` | 0.48 | Surface grip factor, multiplied by tyre-condition grip. |
| `rolling_resistance` | 0.015 | Resistance as a fraction of total axle load. |
| `front_axle_inertia_kgm2`, `rear_axle_inertia_kgm2` | 2.4, 3.2 kg m² | Combined axle rotational inertia. |
| `slip_reference_speed_mps` | 3 m/s | Low-speed slip denominator floor; affects numerical and launch behaviour. |

Changing stiffness does not raise the friction ceiling. Race wear is configured
in [player_state.gd](../game/vehicle/player_state.gd), not this CFG: the nominal
player life is 100 miles, with grip interpolating from 1.00 to 0.92.

## Engine and transmission

Sources: [engine.cfg](../content/vehicles/open_wheel/physics/engine.cfg) and
[gearbox.cfg](../content/vehicles/open_wheel/physics/gearbox.cfg).

| Setting | Authored value | Meaning |
| --- | --- | --- |
| `torque_curve` | See source rows | `Vector3(RPM, closed-throttle Nm, full-throttle Nm)`; interpolated in both RPM and throttle. |
| `idle_rpm`, `redline_rpm` | 2500, 13800 RPM | Idle target and fuel-cut threshold. |
| `inertia_kgm2` | 0.18 kg m² | Engine rotational inertia; larger values slow RPM response. |
| `throttle_rate_s` | 3/s | Maximum throttle-fraction change per second. |
| `idle_control_gain`, `idle_control_max_nm` | 4, 180 Nm | Idle correction gain (torque per angular-speed error) and torque cap. |
| `forward_ratios` | 3.8, 2.95, 2.35, 1.95, 1.65, 1.4 | Lower numeric ratios lengthen gearing and reduce wheel torque at the same engine torque. |
| `reverse_ratio`, `final_drive` | 3.5, 3.9 | Reverse magnitude and multiplier applied to every driven gear. |
| `efficiency` | 0.94 | Clutch-to-axle torque multiplier. |
| `shift_time_s` | 0.16 s | Shift interruption interval. |
| `automatic_upshift_rpm`, `automatic_downshift_rpm` | 13000, 7800 RPM | Automatic shift thresholds, subject to model checks. |
| `launch_rpm` | 4500 RPM | Upper endpoint of the RPM-based clutch engagement ramp. |
| `clutch_capacity_nm`, `clutch_stiffness_nm_s` | 650 Nm, 30 Nm s | Clutch torque limit and slip-speed response. |
| `clutch_engagement_rate_s` | 5/s | Clutch-fraction change limit. |
| `direction_change_max_mps`, `reverse_limit_kph` | 0.5 m/s, 25 km/h | Reverse selection check and assisted speed cap. |

See [gearing](gearing.md) for setup limits and the RPM-to-road-speed formula.
Gearing alone does not establish achievable top speed: drag, rolling resistance,
engine torque and tyre slip also matter.

## Aero and assistance

Sources: [aero.cfg](../content/vehicles/open_wheel/physics/aero.cfg) and
[assists.cfg](../content/vehicles/open_wheel/physics/assists.cfg).

| Setting | Authored value | Meaning and tuning effect |
| --- | --- | --- |
| `air_density_kg_m3` | 1.225 kg/m³ | Scales aerodynamic forces. |
| `body_package` | `speedway` | Selects body coefficients; alternative is `road`. |
| `front_wing_deg`, `rear_wing_deg` | 14°, 8° | Wing angles; affect drag, downforce and balance together. |
| `coefficient_area_scale` | 0.00001720837187 | Converts reconstructed internal coefficients to coefficient-area in m². |
| `assistance_strength` | 1.0 | Master multiplier for the four independent assists. |
| `steering_assistance` | 1.0 | Speed-only range help plus digital-input rate help; zero gives fixed physical lock at every speed. |
| `stability_assistance` | 0.0 | Yaw correction, spin clamp and sideslip damping; zero allows natural rotation. |
| `traction_control` | 0.0 | Driven-axle wheelspin correction. |
| `anti_lock_brakes` | 1.0 | Axle-speed correction to prevent brake lock-up. |
| `steering_response_s` | 0.3 s | Assisted steering response target. |
| `corner_grip_fraction` | 0.85 | Grip allowance used by optional yaw stability and AI speed planning; no effect on steering mapping. |
| `yaw_stability_rate_s` | 14/s | Rate of yaw correction toward the assisted target. |
| `sideslip_damping_rate_s` | 10/s | Exponential lateral velocity damping rate. |
| `traction_slip_limit`, `braking_slip_limit` | 0.06, 0.12 | Slip thresholds for direct axle-speed assistance. |

Drag area, downforce area and front aero fraction are derived outputs, rather
than fixed editable fields in the current aero CFG. See [aero](aero.md).
Tow parameters live in [slipstream.gd](../game/vehicle/slipstream.gd).

## A repeatable tuning pass

Select Race Weekend, choose the track, Continue, then **Private Testing** for a
player-only session. F10 exposes independent assist strengths (0–100%) for that
session; restarting reloads the CFG defaults. Start with the defaults to feel
oversteer. For the forgiving profile, set stability and traction control to 100%.
For persistent changes edit `assists.cfg`; all four controls accept zero.

1. Record the track, effective setup, fuel, tyre condition, input method and assistance strength.
2. Establish a clean-air baseline with telemetry; include a straight, steady corner and braking zone.
3. Change one parameter group and repeat the same manoeuvres.
4. Compare slip, axle loads, grip usage, yaw, RPM and speed as well as subjective feel.
5. Run the relevant [validation checks](player_physics.md#validation) and record results with the revision.

For underlying tyre behaviour, compare a controlled run with handling assistance
at zero; for the player experience, repeat with the intended assistance setting.
Higher grip, stiffness or wing angle can also change assisted steering/yaw limits,
so a handling change may have more than one cause. Keep calibration claims tied
to recorded evidence rather than assuming a plausible value is a measured one.

## Texas lift-off correction (4 October 2026)

The 6/3 Texas telemetry showed a lift/turn-in event at about 329 km/h with little
rear braking slip, followed by rapidly increasing yaw. Load transfer incorrectly
included aero drag and road gravity as if they were tyre forces. The corrected
calculation uses contact forces for pitch balance; coast torque, tyre grip and
stability settings are unchanged. This also changes high-speed balance under power.

The pre-contact input/road replay in `tools/fixtures/texas_lift_6_3.json` reduced
peak sideslip from 6.01° to 3.31°, and peak yaw from 48.99°/s to 26.42°/s. Replaying
the same inputs with 9/3 wings remains substantially looser (12.15° peak sideslip).
These are open-loop force checks using a recorded road environment, not a new
driven lap or a prediction of where the corrected car would travel. The banking
load estimate still uses yaw and velocity and remains an approximation in a spin.

Telemetry now distinguishes `longitudinal_accel_mps2`, `load_transfer_accel_mps2`
and `load_transfer_n` (positive transfers load rearward). The regression also
checks that CG drag alone causes no transfer, braking/traction still do, and the
6/3 response agrees at 60 and 120 Hz. Power-on oversteer/recovery remains covered
by `validate_oversteer.gd`.

## Texas steering assistance follow-up (4 October 2026, superseded)

The subsequent 6/3 run showed full-left input held steady while the road-wheel
angle rose from about 1.0° to 1.6° during a lift. The grip-derived range expands
as speed falls and yaw-generated bank support rises. This can amplify rotation
even when the driver adds no steering.

Range expansion now approaches its target with a 1-second time constant at
50 m/s and above, fading out below that to immediate updates at 20 m/s. Range
reductions remain immediate, and countersteering retains its existing additional
travel and base steering rate. The equilibrium range, tyre curve, peak friction,
downforce, load-transfer correction and engine braking are unchanged. This is
assistance tuning; the yaw-based bank-load approximation remains in the core model.

With the recorded inputs/road environment, entry-event peak sideslip changes
from 9.37° to 3.75° (yaw 80.68°/s to 32.08°/s), and the late-event peak changes
from 13.18° to 4.27° (yaw 82.91°/s to 27.98°/s). The exit event stays comparable,
4.28° to 4.11°. These remain open-loop model comparisons, not fresh driven laps.
`validate_lift_off.gd` covers all three recordings at 60/120 Hz, steady steering
range, immediate range reduction and reset. Telemetry includes
`assisted_steering_lock_deg` before the extra countersteering allowance.

## Predictable steering mapping (4 October 2026)

The follow-up above reduced lift transients but still restricted corner entry.
Speed steering help now uses only the configured low/high-speed travel and speed
threshold. Grip-derived range, range recovery filtering and slide-dependent
countersteer gain have been removed. Tyre, aero, load-transfer and engine-braking
parameters are unchanged. `corner_grip_fraction` still affects optional yaw
stability and AI speed planning, not the input-to-angle mapping.

F10 **Speed steering help** defaults to 100%: full normalized input means 4.5
road-wheel degrees at 270 km/h and above, rising to 28 degrees at rest. At 0%,
full input means 28 degrees at every speed. Digital input retains a steering-rate
limit in both modes; calibrated wheel input bypasses it as of the 5 October fix
described below. Master strength scales this option too. Compared with the old approximately
1–1.6 degree Texas range, less wheel rotation is now needed for the same corner.
Steering calibration is retained. Wing adjustments affect forces, not steering
sensitivity at a given speed. The bicycle AI uses the same mapping helper when
converting its desired road-wheel angle into normalized input.

`validate_steering.gd` checks range/rate independence from wings, grip, yaw,
slides and contact, plus fixed angle through a high-speed lift at 60/120 Hz.
Telemetry's existing `assisted_steering_lock_deg` now reports effective travel,
including the master/help blend, with no hidden countersteering allowance.

Old recorded normalized inputs cannot be replayed directly: the new mapping
would command much larger road-wheel angles. `validate_lift_off.gd` keeps each
recording's input changes but freezes its input-to-angle scale at the initial
recorded steer/input ratio. This is a controlled angle-scale experiment using
recorded road conditions, not an exact replay or fresh driven lap. Peak sideslip
at 6/3 is 2.43, 3.24, 8.13 and 3.75 degrees for the original, entry, exit and late
fixtures. The exit slide is larger because the assistance no longer reduces
steering as grip changes; the driver must unwind/correct. Its regression envelope
is explicitly 9 degrees and 40 deg/s yaw rather than the earlier assist-dependent
4.5/28 limits. The matched-angle original fixture remains looser at 9/3 (3.60
degrees), and all fixtures agree within 0.01 degree at 60/120 Hz.

The power-oversteer and road-support checks now request road-wheel angles rather
than reusing obsolete normalized inputs. Mirrored power slides remain catchable
with an early lift/countersteer (4.14 degree peak); holding power and steering can
still spin the car. This establishes steering behaviour, not validated real-world
handling. At that stage, left/right wheel loads and tyre load sensitivity remained future work.

Validation note: the legacy bicycle-AI lap test still fails during pit exit with
both the previous steering code and this mapping. Its departure timing is now
fixed in the test (normal practice randomises release over seven minutes, longer
than the three-minute test). This is not a passing AI handling regression; default
ICR2 opponents use a separate movement controller. Private Testing passed on all
four tracks. The wheel UI check opens the actual Controls page before checking
setup braking and toggles speed steering help through its UI control.

## Four tyre loads and roll balance (4 October 2026)

See [tyre loads](tyre_loads.md). The pre-change parameter snapshot, source hash,
Texas replay metrics and latest driven-session summary are preserved in
[the baseline fixture](../tools/fixtures/texas_before_four_tyre_loads.json).
The local model/config source copy is in `tmp/four_tyre_baseline`.
The steering mapping, aero coefficients and engine braking have not changed.

With 50% front roll stiffness and the mild 0.98 peak-load exponent, the original
6/3 replay peak sideslip is 2.44 degrees (baseline 2.43); 9/3 is 3.73 (3.60).
Entry/exit/late cases are 3.28/7.78/3.82 versus 3.24/8.13/3.75 degrees. Existing
replay limits remain unchanged, including 60/120 Hz agreement. These are fixed
angle-scale experiments, not driven laps. A stronger 0.92 exponent was rejected
for the initial tune because it sharply amplified the difficult lift cases.
The provisional coefficient is chosen to preserve the usable baseline, not to
claim a measured IndyCar tyre fit. Roll balance affects handling even with this
mild peak-load exponent because per-wheel cornering stiffness also depends on load.

The controlled 45 m/s, 4-degree sustained corner produces 0.518 rad/s yaw at
35% front roll stiffness and 0.512 at 65%, mirrored left/right. The 200 km/h
banked-corner radius is 116.95 m versus 116.12 m before this step. Mirrored
power-slide recovery peaks at 3.98 degrees and remains catchable.

## Surfers Paradise clutch and wheel response (5 October 2026)

The 17:54 recording used automatic gears, the G29, road aero at 14/14 degrees,
57% front brake bias, ABS enabled and stability/traction assistance disabled.
Its original model replay is reproducible to small initial-state differences,
but engine/clutch state is not completely recorded in that older CSV.

The former approximately 0.98 ms integration step exceeded the first-gear
clutch mode's approximately 0.95 ms explicit stability limit. At constant 20%
throttle and 70 km/h, clutch torque oscillated between about -629 and +650 Nm;
halving and quartering the step both produced smooth torque near +11 Nm.
Integration now has a 0.5 ms ceiling and a tighter ratio/inertia-dependent clutch
bound. The physical torque curve, brake bias, tyre coefficients and clutch
stiffness are unchanged. New tests include shorter gearing and a stiffer clutch.

Calibrated wheel steering bypasses digital steering slew. The existing optional
speed-dependent range remains; keyboard steering retains its rate limit.
In the recording near 188.7 s, the input asked for approximately 8 degrees of
countersteer while the old front-wheel angle still pointed 1 degree into the turn.

Peak body sideslip in selected recorded-input windows, in degrees:

| Window, elapsed seconds | Original model | Both fixes |
| --- | ---: | ---: |
| 93.5–96.5 | 24.98 | 25.34 |
| 129.5–132.0 | 25.25 | 10.62 |
| 170.5–173.0 | 12.48 | 3.63 |
| 186.5–189.0 | 22.36 | 6.35 |
| 270.5–273.2 | 25.43 | 26.19 |

These are open-loop comparisons, not lap replays: original corrections are
repeated even when the modified car responds differently. Some other windows
worsen. The saved `surfers_handling.json` fixture covers both improvements and
remaining higher-gear slides, with agreement within 0.05 degrees at 60/120/240 Hz.

The remaining slides involve combined braking/cornering demand and the rear
tyres passing their force peak, sometimes followed by power-on wheelspin.
With both fixes active, halving the provisional closed-throttle torque reduced
the 93.5 s window from 25.34 to 7.01 degrees, but worsened the 348.5 s window
from 20.60 to 28.09 degrees. Removing post-peak force falloff improved the former
to 15.45 degrees, but worsened the 283.5 s window from 22.54 to 43.74 degrees.
Neither experiment establishes a calibrated engine or tyre model; neither was
applied. A fresh driven run with the corrected wheel response is the next useful
comparison before changing those physical parameters.

Telemetry now appends gearbox mode, actual steering source, clutch engagement,
minimum/maximum clutch torque within each tick, effective engine throttle
opening (including rev matching), and integration substep count. These fields
expose the input mode and torque oscillations that the old 60 Hz rows concealed.

A local headless 1,200-tick microbenchmark measured about 0.64 ms per player-model
tick in first gear and 0.50 ms in sixth (previously 0.24 ms for each). This is
model CPU time only, not a rendered frame-rate measurement.

## Surfers tyre falloff comparison (6 October 2026)

Decision: retain `post_peak_falloff=2.0`. Neither 3.0 nor 4.0 consistently
improved the recorded cases. This experiment changes only the falloff width,
equally on both axles. Peak grip, small-slip stiffness, the 85% sliding asymptote,
engine braking, 57% front brake bias, assists and the steering/driveline fixes
remain unchanged in the driving configuration.

`tools/compare_tyre_falloff.gd` replays six slide windows and three cleaner
windows from `practice_2026-10-05T18-21-22_9372.csv`. The portable fixture is
`tools/fixtures/surfers_tyre_falloff.json`; its physics metadata is identical to
the existing `surfers_downshift.cfg`. All windows exclude wall contact and start
with an engaged clutch. The baseline reproduces recorded body sideslip to within
0.005 degrees. These are open-loop input comparisons, not predicted lap times
or proof that a human driver could not catch the altered response.

Peak absolute body sideslip, degrees:

| Window, elapsed seconds | Width 2 | Width 3 | Width 4 |
| --- | ---: | ---: | ---: |
| Brake to power, 38–41.8 | 20.76 | 13.14 | 12.41 |
| Heavy trail braking, 140–144.2 | 31.77 | 53.90 | 56.87 |
| First-gear exit, 159–163 | 34.13 | 36.49 | 34.38 |
| Direction change, 304–308.1 | 20.31 | 24.53 | 22.00 |
| Fast entry, 430.5–434 | 32.41 | 29.16 | 21.78 |
| Late braking entry, 463–467.5 | 37.01 | 39.10 | 33.11 |
| Cleaner entry, 337–341 | 2.24 | 2.24 | 2.24 |
| Cleaner exit, 387–391 | 3.55 | 6.74 | 8.70 |
| Cleaner fast section, 371–375 | 3.04 | 3.04 | 3.04 |

Controlled tests use the same steering feedback for each candidate, mirrored
left/right, with a correction triggered at 3 degrees body sideslip after a
0/0.1/0.2 s delay. They record peak yaw, rear lateral-force history and sampled
force-loss rate before correction, as well as peak sideslip and recovery time.
The controller is a repeatable experiment, not a calibrated driver model.
Recovery requires body sideslip below 1 degree and yaw rate below 0.05 rad/s
for 0.3 s without stopping or reversing.

With a 0.2 s correction delay, the power-slide peak falls from 11.22 to 9.44
and 8.18 degrees; recovery after correction falls from 0.567 to 0.467 and
0.433 s. The braking-slide peak barely changes: 8.97, 8.85 and 8.80 degrees,
with recovery at 0.367 s for all widths. Holding power and steering instead
of correcting gives peaks of 34.18, 30.84 and 26.20 degrees in this particular
test. Holding brake/steering can still spin every candidate. Wider falloff is
therefore more forgiving in the power test, but not a demonstrated remedy for
the remaining braking problem.

Steady 90 and 200 km/h two-degree corners give identical equilibrium results
for all widths. Force-budget, pre-peak stiffness, sliding asymptote and symmetry
checks pass. Separate existing oversteer and 200 km/h banked-corner checks pass
with the retained driving configuration.

Numerical limitation: halving the integration step changes the severe baseline
trail-braking peak from 31.77 to 34.75 degrees; quartering gives 36.08 degrees,
with unchanged gear-transition ticks. This window is flagged as sensitive,
not claimed to have passed a 0.5-degree convergence check. All other windows and
both wider candidates change by less than 0.36 degrees when the step is halved.
Changing the outer update frequency also moves automatic-shift decisions, so
the retained refinement test holds input/gearbox update cadence at 60 Hz and
refines only force integration. The result does not support promoting a wider
curve; numerical sensitivity and front/rear combined-force balance need further
investigation before another tuning decision.

Run `godot --headless --path . --script res://tools/compare_tyre_falloff.gd`.
It writes diagnostic traces to `tmp/tyre_falloff_comparison.json` and leaves
vehicle settings untouched. Harness success means its invariant/reproduction
checks passed; it does not mean either candidate is approved for driving.

## Front/rear force balance investigation (6 October 2026)

The remaining slides have different mechanisms; the logs do not support a
single abrupt rear-force collapse. Reconstructing the per-tyre force vectors
from recorded load, slip and grip matches recorded axle force usage to within
2.4e-7. The axle-to-body force rotation and yaw moment signs were inspected:
front braking force also has a body-lateral component when the wheels steer.
No force-sign or lever-arm error was identified in this investigation.

The CG is 1.6074 m behind the front axle and 1.2126 m ahead of the rear axle.
Equal axle lateral forces therefore do not balance yaw. At small steer and
negligible longitudinal contribution the rear must provide 57% of lateral force
for zero net yaw moment; this is a geometric requirement, not a brake-bias target.
Use full rotated forces for actual moment calculations.

**Heavy braking, 143.5 s:** rear normal-load share is 41.71% (4.14 kN rear,
5.79 kN front). Both axles are past their combined-force peak. Front and rear
wheel-coordinate lateral forces are -4.21 and -4.36 kN. After rotating the front
force into body axes, its yaw moment is -6.24 kNm; the rear opposes it with
+5.28 kNm. The remaining -0.96 kNm accelerates the existing clockwise rotation.
Braking has substantially changed the load/force balance even with 57% front
brake bias. At 143.9 s, front braking acting through positive countersteer adds
-0.90 kNm in that rotation direction. This follows from force-vector geometry;
removing it is not a physical correction and worsens most replay windows.

**Fast entry, 433.12 s:** rear lateral force is still -9.08 kN. Front/rear yaw
moments nearly balance (-11.18/+11.01 kNm), yet yaw rate is approximately
-70 deg/s and sideslip is 14.7 degrees. The body-frame `u*yaw_rate` term is
-48.0 m/s² while tyre lateral acceleration is only -20.45 m/s². Even near-zero
net yaw moment cannot immediately stop that rotation, and lateral velocity
continues building. At 466.52 s a similar mismatch remains (31.57 versus
19.96 m/s²), although the net moment is already opposing rotation. These cases
include accumulated rotation and limited recovery, not disappearing rear force.

**Cleaner exit, 389.42 s:** rear force is 7.66 kN versus 5.48 kN at the front,
and the rear provides a modest restoring moment. The corresponding acceleration
terms are much closer (19.53 versus 16.67 m/s²); body sideslip is only -1.68 degrees.

Isolating wider falloff at each axle explains part of the failed global change:

| Recorded-input window | Baseline | Front width 4 only | Rear width 4 only |
| --- | ---: | ---: | ---: |
| Heavy trail braking | 31.77° | 31.34° | 49.28° |
| First-gear exit | 34.13° | 46.05° | 16.54° |
| Fast entry | 32.41° | 35.38° | 21.26° |
| Cleaner exit | 3.55° | 16.02° | 3.41° |

Retaining more front force after its peak can increase the turning moment enough
to worsen a previously cleaner corner. Wider rear falloff helps several windows,
but still worsens heavy braking and is not accepted as a default. Reducing engine
braking, lowering the ABS slip limit or removing roll transfer also gives mixed
results. Diagnostic removal of pitch transfer changes both braking and power-on
balance and severely disrupts several windows; it cannot be treated as a targeted
braking fix. All these comparisons repeat the original driver's controls after
the trajectory changes, so they establish sensitivity, not driver adaptability.

The heavy-braking numerical sensitivity was followed further at the same 60 Hz
input cadence:

| Integration ceiling | Peak sideslip |
| --- | ---: |
| 0.5 ms | 31.77° |
| 0.25 ms | 34.75° |
| 0.125 ms | 36.08° |
| 0.0625 ms | 36.72° |
| 0.03125 ms | 37.03° |

The clutch-specific step bound is scaled by the same factor. Gear-transition
ticks remain identical. Compared with the finest run, body sideslip first differs
by 0.1 degree at 143.067 s, 0.5 degree at 143.45 s and 3 degrees at 143.983 s.
The error accumulates through the reversal rather than originating in different
shift decisions. Refinement increases the eventual slide, so the spin is not an
artifact that disappears at higher accuracy. The present solver underestimates
its severity. Resolving this accuracy limit is a prerequisite to confident
fine tuning of this window; it is not itself a demonstrated handling cure.

`tools/investigate_force_balance.gd` preserves this investigation using the
portable fixture. It writes `tmp/force_balance_counterfactuals.json`, including
axle force/moment traces. No production physics, brake bias or tyre defaults were
changed. Next work should establish an integration accuracy target for the
braking reversal, then assess transient axle/yaw balance with controlled steering
and recovery tests before adopting any axle-specific tyre calibration.

## Integration accuracy experiment and controlled recovery (6 October 2026; withdrawn)

**Status: withdrawn from gameplay.** The CPU cost was not justified by a demonstrated
handling improvement. The previous clutch-bounded Euler model is restored, including
the automatic downshift, stable clutch and direct wheel steering fixes. Brake bias
remains 57% and tyre falloff remains 2. The results below describe the withdrawn
experiment, retained in `tools/fixtures/step_doubling_reference.gd`;
`validate_integration_accuracy.gd` now tests that offline reference only. New gameplay
logs identify `bounded_euler_v1` and its normal step ceiling. The original severe
braking timestep sensitivity remains unresolved.

Rollback verification: driving physics matches the pre-experiment source exactly,
apart from the telemetry scheme identifier. Interleaved benchmarks against that
saved source measured 0.627 vs 0.615 ms in first gear, 0.474 vs 0.473 ms in sixth,
and 0.615 vs 0.617 ms during partial clutch engagement (median tick times).
The extra integration CPU cost is removed.

The experimental model used explicit second-order step doubling. Each numerical
step compares one full Euler trial with two half trials and cancels the leading
error in the body, axle/engine and load-response states. Trial state is restored
including clutch, shift clock, rev-match flag, wake history and heading. Bounded
controls and discrete events follow the half-step path; stopped states, idle,
full ABS/TC and hard speed limits remain constrained. This changes numerical
accuracy, not tyre grip, brake bias, engine torque or driver assistance settings.

The 0.5 ms ceiling and ratio-dependent clutch bound remain. Shifts and moving
clutch reconnection use at most 0.125 ms steps, because their non-smooth control
transitions did not meet the full-trace accuracy target at the normal step.
The extra refinement is skipped for an unloaded clutch with a tenfold torque
margin; this avoids refining stable low-torque operation just because engagement
is below one. Full shift-cut intervals remain refined. Per-wheel telemetry-only
arithmetic is skipped on the discarded full trial and intermediate half step.
Automatic gear decisions still occur once per outer tick. Telemetry's
`integration_steps` counts numerical steps, each containing three force
evaluations; rejected full-step trial torques do not contaminate clutch extrema.
New telemetry metadata identifies `step_doubling_v1` and both step ceilings so
future recordings can be distinguished from the old solver at identical setups.

The new `validate_integration_accuracy.gd` checks every sample of all nine
recorded-input windows against halved steps, with fixed 60 Hz input/gearbox
cadence. Acceptance is less than 0.2 degrees body sideslip and 0.5 degrees/s yaw
difference over the entire trace, not merely agreement of peak values. Observed
maxima are 0.070 degrees and 0.315 degrees/s. Forward/reverse braking-to-rest
checks also preserve stopped wheels and bounded controls.

For the sensitive heavy-braking window:

| Solver | Peak sideslip |
| --- | ---: |
| Previous production Euler solver | 31.774° |
| Withdrawn step-doubling experiment | 37.3442° |
| New solver, halved steps | 37.3443° |
| Independent Euler reference, 15.625 microsecond ceiling | 37.1853° |
| Independent Euler reference, 7.8125 microsecond ceiling | 37.2616° |

The new solver's full sideslip trace differs by less than 0.001 degrees when its
step is halved. It also agrees with the finer independent first-order reference
within the separate 0.2-degree / 0.5-degree/s limits. The independent reference's
own sideslip change is below 0.1 degrees on refinement. This fixes the accuracy
defect; it does not make the severe recorded slide disappear.

Historical falloff/force-balance tables above describe the earlier first-order
model. Their scripts now run the current model and report differences from the
historical recording without treating the old trajectory as numerical truth.

`compare_axle_recovery.gd` tests power-on breakaway, brake turn-in and a heavy
braking steering reversal with a state-feedback correction after 0/0.1/0.2/0.3 s.
Each scenario is mirrored. Early corrections up to 0.2 s must recover; 0.3 s is
a late-correction stress case whose success is reported rather than assumed.
This synthetic controller is identical across candidates and is not a measured
human-driver model. The comparison varies front/rear falloff independently,
without changing the driving configuration.

At a 0.2 s delay, peak sideslip in degrees:

| Scenario | Current tyres | Front width 4 only | Rear width 3 only | Rear width 4 only |
| --- | ---: | ---: | ---: | ---: |
| Power slide | 11.21 | 11.21 | 9.43 | 8.17 |
| Brake turn-in | 8.94 | 9.24 | 8.65 | 8.54 |
| Heavy-braking reversal | 11.50 | 12.21 | 10.84 | 10.58 |

Rear-only broadening improves these controlled catches; retaining more front
force worsens braking recovery. At a 0.3 s delay, the baseline heavy reversal
still reaches approximately 49 degrees, so late corrections remain a serious
limit. These findings justify further rear-specific calibration work, but do
not override the adverse recorded heavy-braking replay. Rechecking that replay
with the corrected solver gives 37.34 degrees with current tyres, 50.06 with rear
width 3 and 49.57 with rear width 4. This confirms the regression survives the
accuracy correction. Tyre
falloff remains 2.0 and front brake bias remains 57%; only the accuracy correction
is enabled for the next driven run.

Validation passed: integration accuracy, driveline, bicycle, gear shifts,
steering, oversteer, stability, tyre loads, Surfers handling, lift-off, cornering,
telemetry and the axle-recovery comparison. Godot's existing root certificate
store warning was unrelated to these headless checks.

CPU tradeoff: the withdrawn solver performs three force evaluations per step.
Skipping intermediate diagnostic arithmetic and low-torque clutch refinement
avoids unnecessary work, but accuracy still costs more. An interleaved local
headless cruise benchmark measured about 1.5–2.0 ms per player tick, versus
0.48–0.63 ms before. In separate recorded-input profiling, loaded shift/reconnect
windows had 95th-percentile model times around 7–16 ms; the machine's timings
varied during the run. These are CPU-only timings, not rendered frame rates.
Cheaper fixed/adaptive schedules were tested but rejected because they failed
the same full-trace accuracy limits. Rendered performance during repeated
downshifts remains a limitation to check in the next driving session.
