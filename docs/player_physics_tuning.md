# Player physics: tuning reference

[Back to the overview](player_physics.md). Authored settings checked on
30 September 2026. These are prototype defaults, not measured vehicle data.

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
| `cg_height_m` | 0.32 m | Higher values increase longitudinal load transfer. |
| `yaw_inertia_kgm2` | 1000 kg m² | Dry reference inertia; higher values slow force-driven yaw response. |
| `brake_force_n`, `front_brake_bias` | 18000 N, 0.57 | Total brake setting and front fraction; more forward bias shifts braking demand to the front. |
| `steering_lock_deg`, `high_speed_lock_deg` | 28°, 4.5° | Base low/high-speed lock before grip-based assistance. |
| `steering_reduction_speed_mps` | 75 m/s | Speed at which base lock reaches its high-speed value. |
| `steering_rate_deg_s` | 35°/s | Maximum base steering rate. |
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
| `friction_coefficient` | 1.65 | Combined-force ceiling per unit normal load. |
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
| `assistance_strength` | 1.0 | Handling intervention strength, from 0 to 1. |
| `steering_response_s` | 0.3 s | Assisted steering response target. |
| `corner_grip_fraction` | 0.85 | Grip allowance used by steering/yaw assistance. |
| `steering_range_multiplier` | 1.25 | Extra assisted steering travel to account for tyre slip. |
| `yaw_stability_rate_s` | 14/s | Rate of yaw correction toward the assisted target. |
| `sideslip_damping_rate_s` | 10/s | Exponential lateral velocity damping rate. |
| `traction_slip_limit`, `braking_slip_limit` | 0.06, 0.12 | Slip thresholds for direct axle-speed assistance. |

Drag area, downforce area and front aero fraction are derived outputs, rather
than fixed editable fields in the current aero CFG. See [aero](aero.md).
Tow parameters live in [slipstream.gd](../game/vehicle/slipstream.gd).

## A repeatable tuning pass

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
