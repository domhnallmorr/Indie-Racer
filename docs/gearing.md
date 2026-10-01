# Gearing setup

Park in your practice or qualifying pit box, open the pit monitor with Enter,
then choose **Edit Car Setup → Gearing**. Adjust final drive and all six forward
ratios. Apply saves them for this track, including subsequent qualifying and race
sessions. Changes cannot be applied during a race. Leaving without applying
discards the edits when the page is reopened.

Lower numeric ratios lengthen gearing: more road speed at the same engine RPM,
less wheel torque. Final drive affects every gear, including reverse (the
existing reverse speed limit remains active). Individual gear ratios affect
only that gear. Ratios must strictly decrease from first to sixth. Setup limits
are 2–6 for final drive and 0.5–5 for individual forward ratios.

The preview shows each gear's speed at the automatic upshift threshold and at
redline. Sixth has no automatic upshift. These are zero-slip kinematic speeds:

`speed_kph = RPM / 60 × 2π × rear_tyre_radius / (gear_ratio × final_drive) × 3.6`

Actual top speed also depends on engine torque, drag, rolling resistance and
tyre slip. The existing automatic shift logic and engine curve remain active.
Gearing changes do not change redline or add engine power.

## Texas baseline

Texas now defaults to a 3.40 final drive, using the existing gear ratios
`[3.8, 2.95, 2.35, 1.95, 1.65, 1.4]`. With the 0.34 m driven tyre radius and
13,800 RPM redline, sixth gives approximately 372 km/h at redline and 12,812 RPM
at 345 km/h. This provides room above the previous roughly 324 km/h limit.
It is a provisional tuning setup, not a recovered historical gear set or a
promise of achievable speed. Other tracks retain the authored 3.90 final drive
unless overridden by a saved setup.

Saved setups live in `user://gearing_setups.cfg`, keyed by track session path.
Valid saved values override the default. Physics metadata and per-tick CSV
telemetry record final drive and all six ratios, including changes made during
a recording. Applying while parked resets clutch/axle state.

Player telemetry starts automatically when a driving session finishes loading.
F11 still stops or resumes recording for that session. Recordings and matching
setup metadata are saved in `user://telemetry`; leaving the session flushes and
closes the file. Existing recordings are not automatically deleted.

Next driving comparison: use the same fuel and wings, record corner and straight
speeds plus RPM, then adjust sixth/final drive so clean-air running is not pinned
at redline. Aero and cornering calibration can then be assessed at those speeds.
No runtime tests or driving calibration were performed for this implementation.
