# Rear differential

The rear differential model is the default and only player handling model. Each
wheel has its own rotational speed, and a bounded friction clutch couples the
rear wheels. Earlier axle, shared-front, free-front/shared-rear and stagger
variants have been removed. Old saved handling selections are ignored.

Open **F10 → Rear Differential** in a driving session to adjust:

| Control | Default | Meaning |
| --- | ---: | --- |
| Drive locking | 30% | Coupling capacity while the driveline supplies power. |
| Coast locking | 10% | Coupling capacity while the wheels drive the engine. |
| Preload | 20 Nm | Minimum coupling capacity, including neutral. |

Changes apply immediately. Pit resets retain the settings; new sessions restore
the defaults. Settings are session-only and are not saved as car setup.
More locking resists wheel-speed differences. All three at zero give an equal-
torque open differential. 100% does not guarantee a permanently locked axle.
Drive/coast selection follows mechanical power, including reverse and engine
braking, rather than pedal position.

## Implementation

Each wheel carries half its authored axle inertia and brake torque. The rear
carrier speed used by the engine/clutch and RPM calculations is the mean of the
rear wheel speeds. Each rear wheel receives half the axle input torque and its
own tyre reaction. ABS and traction control use individual contact speeds.
Full wheel-force yaw moments remain in body integration. Rear tyres have equal
radii; the stagger experiment has been retired.

```text
capacity = preload + 0.5 * abs(axle_input_torque) * selected_lock_factor
equalisation_torque = wheel_inertia * (omega_right - omega_left) / (2 * dt)
coupling_torque = clamp(equalisation_torque, -capacity, capacity)
omega_left  += coupling_torque * dt / wheel_inertia
omega_right -= coupling_torque * dt / wheel_inertia
```

Coupling follows the tyre/drive/brake impulse update. Equal and opposite torques
preserve carrier speed. The equalisation bound prevents overshoot and removes
rotational energy without creating it. Dissipated energy accumulates over each
physics tick. The first integration step seeds wheel states from mean speeds.
Reset clears rotational state while retaining session settings.

This simplified symmetric clutch has no ramp geometry, clutch temperature,
wear or calibrated static/dynamic friction transition. It is not a reconstruction
of ICR2's differential. The earlier [investigation](rear_axle_investigation.md)
is retained as historical evidence; its viscous damping hypothesis and numerical
settings are not interchangeable with this friction clutch.

## Telemetry and validation

Telemetry retains `wheel_contacts_rear_differential_v1` and records both rear
angular speeds, drive/coast factors, preload, selected phase, torque capacity,
signed coupling torque and dissipated joules per tick. Positive coupling torque
transfers angular momentum from the faster right wheel to the left. Sidecar
metadata retains `bounded_clutch_hypothesis_v1` with `icr2_verified = false`.
Existing CSV columns remain compatible: retired stagger columns record zero and
equal rear radii. CSV rows record settings changed after recording starts.

`tools/validate_rear_differential.gd` checks torque balance and energy dissipation,
drive/coast classification in forward/reverse, capacity and equalisation bounds,
invalid settings, airborne behaviour, straight symmetry, individual ABS/TC limits,
reset/default startup, mirrored recovery, numerical refinement, live F10 controls
and telemetry. It also compares open and stronger locking. Reusable recovery
cases live in `tools/fixtures/rear_wheel_cases.gd`. Results go to
`tmp/icr2_analysis/rear_differential_validation.json`.

The synthetic delayed-power correction case reaches about 32.0 degrees and
recovers at the defaults. An open axle stays below the correction threshold in
that power test but rotates more under braking. These controller-based results
demonstrate different handling, not a claim that one setting improves every
corner or reproduces human driving.
