# ICR2 method — two-car circulation prototype

Practice defaults to **ICR2 method — 15-car field**, restoring every Club 1996
driver with ICR2 reference driving. Pace targets interpolate the prior seed-1234
clean-air results between Casey Grant at 21.2 s and Finley West at 22.8 s.
The roster is `content/rosters/icr2_full/manifest.json`; each driver's `icr2_lap_s`
is editable. The two-car ICR2 test roster and original bicycle-based 15-car roster
remain available through F12. Player handling is unchanged.

Cars are assigned boxes in pace order, with Casey in the forward box departing
first. The aligned inside/outside corridor paths act as initial `PASS1`/`PASS2`
alternatives to `race.lp`: traffic selection and transitions are shared with the
two-wide prototype, while `race.lp` remains the clean-air pace reference. A 1.02
passing-speed factor is authored in the game-wide `content/racecraft.json` tuning
file. Following, blocked
departure and merge yielding remain active. Driver targets are fixed for repeatable
comparison; random form and bicycle-era driver ratings do not alter this prototype.

The isolated two-car pace test uses each entry's `icr2_lap_s` in
`content/rosters/icr2_test/manifest.json`. Casey now targets 21.2 seconds and Finley
22.8 seconds. This scales corner pace in the recorded reference speed profile;
near top speed it blends to a +/-2% variation around the player reference.
The same scaling applies at the end of pit exit. Smaller values mean faster pace,
but these are pace ratings rather than exact lap guarantees. The recorded
braking/acceleration locations remain the reference.
The three-minute roster-pace test measured bests of 21.192 s and 22.792 s, with
zero contacts, pit-limiter compliance and maximum racing line error below 1.05 m.
Traffic and alternate-line use can prevent these clean-air times.

`game/vehicle/icr2_car.gd` integrates scalar speed with 8 m/s² acceleration and
18 m/s² braking limits and follows a lookahead target. It uses CharacterBody3D
collision movement and the existing road-step support, pit-zone checks and visible
banking alignment. It does not instantiate or advance the bicycle model. Turning
is bounded by a simple 65 m/s² lateral acceleration envelope and 1.6 rad/s yaw
limit. These are kinematic tuning limits, not a tyre or load-sensitive simulation.

`game/ai/icr2_driver.gd` reuses existing departure geometry, path progress and merge
checks. Race speed is interpolated by distance along the existing racing line.
Large line errors reduce speed. It does not compute racing corner speeds from
grip each tick. Actual speed is constrained by acceleration, braking, traffic and
collisions; a lap-time target is not a guarantee of the measured lap time.

## Reference files

- `content/tracks/mile_oval/ai/race.lp.json`: 805 speed samples plus the corresponding
  reference points, in metres and seconds. This is our JSON format, **not binary
  compatible with an original ICR2 race.lp**. Runtime rejects a stale racing line.
- `pit_out.lp.json`: authored departure/cruise/merge settings over the existing
  per-box exit route. The geographic 80 km/h limiter always takes priority.

Pit-out cruise is 180 km/h once outside the limiter, with the ramp toward racing
speed starting 340 m before the route joins the racing line. The former 120 km/h
cruise and 160 m ramp held cars at 120 well onto the backstraight. Stall departure
retains its 55 km/h ceiling. Acceleration remains bounded by the movement controller,
and conflicting traffic can still cause yielding before merge commitment.

The pit-out calibration run measured 232–234 km/h average along the backstraight
exit lane (track-local x=60..180 m, z < -100 m) and 291–294 km/h at the merge.
Casey joined at 28.68 s instead of 34.05 s, Finley at 35.17 s instead of 40.48 s.
Maximum pit-route tracking error was 1.54 m, with zero vehicle contacts and full
80 km/h limiter compliance in the three-minute test. The circulation validator
checks exit-lane speed and merge speed separately from racing lap pace.

The current race profile comes from the player's 13 September 08:53 F11 recording.
`python tools/build_icr2_profile.py --telemetry "PATH_TO_CSV"` selects the fastest
complete lap through all four ordered timing gates, excluding laps with pit-zone,
grass or airborne samples. It projects recorded positions onto the existing line
and interpolates speeds by distance, with approximately six metres of smoothing.
Recorded sample indices are never used as track indices. The source filename,
SHA-256, row interval and lap times are recorded in the generated profile.

The chosen player lap is 22.217 s (the other complete clean lap was 22.438 s), with
216.3–308.3 km/h speeds. Measured reference speeds are not normalized to an arbitrary
lap time during import. Runtime retains the small per-driver pace scaling to the
roster targets. The existing AI line is retained, so its distance-integrated profile
time is 22.052 s rather than the player's 22.217 s. A later import could replace
the line as well, but that is not needed for this speed-distribution correction.

This replaces the provisional AI capture, whose speed distribution was wrong even
though its total lap time passed. In the defined regions (|x| < 180 m for straights,
|x| > 260 m for corners), that old profile averaged 267.5 and 282.1 km/h respectively.
The new spatially sampled profile averages 288.7 and 228.2 km/h. The generated
profile is content; the original CSV is only needed to rebuild or audit it.

## Recording a better reference

No new recording is required to try this version. To update the
profile with another recording, press **F11**, drive at least two consecutive clean
flying laps, then press F11 again. The existing player telemetry records track-local
XYZ position, speed and time each physics tick. The Output log prints the CSV path
under Godot's `user://telemetry` directory. Keep the accompanying CFG metadata.

We can extract a complete start/finish-to-start/finish lap and resample its line
and speed by distance. Using the recorded line together with its speed avoids
assuming the same braking points suit a different groove. Actual throttle/brake
inputs are useful diagnostics but not required for the reference controller.

A pit-out recording is optional. The authored route already covers stall departure,
the limiter, apron and merge. A later recording can refine the shared exit section;
each stall still needs its own connection to that route.

## Validation

`tools/validate_icr2.gd` runs three simulated minutes at the normal 1/60-second step,
starting in the real pit boxes. It checks repeated timed laps, pace ordering, line
tracking, road clearance, pit limiting and vehicle contacts. It writes per-car CSVs
and `builds/icr2_validation.json`. `tools/capture_icr2.gd` captures a rendered corner.

The player-profile run measured Casey at 22.285 s (six timed laps) and Finley at
22.581 s (five), maximum target-line error about 1.01 m, maximum road-centre offset
7.17 m and zero vehicle-contact ticks. `tools/validate_icr2_profile.py --telemetry
"PATH_TO_CSV"` additionally compares the captured straight/corner means against the
selected player lap, allowing for driver scaling, and checks speed-target tracking.
This validates ordinary circulation, not arbitrary player impacts or crash recovery.

`tools/validate_icr2_field.gd` checks all 15 pit assignments and five simulated
minutes of departures and circulation, including vehicle contacts, road clearance
and the pit limiter. Traffic can prevent clean-air target lap times while passing
is disabled.
