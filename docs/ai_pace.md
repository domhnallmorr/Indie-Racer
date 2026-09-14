# Mile Oval pace calibration — 12 September

The current Club 1996 field is calibrated around a 22.4-second midfield lap.
The user estimated approximately 22 seconds; the earlier recorded player reference
was 22.412 seconds. An exact 22.000 would still beat this field in clean air.

The line generator now smooths its horizontal path over +/-120 m instead of
+/-45 m. Raw lateral offsets run from +6 to 0 m before smoothing; the resulting
line uses the outside straights and a roughly -7.1 m apex. Heights are reprojected
onto the road. The passing corridor is regenerated against this same line.
This removes entry/exit curvature peaks that forced the old driver to slow down.
Increasing corner targets on the old line alone produced understeer and slower laps.

The track profile uses 0.97 cornering utilisation, 0.90 braking utilisation and
the existing 5 m braking margin. Its optional `minimum_cornering_factor` is 0.97:
cornering ratings interpolate from that factor to 1.0. Other profiles that omit
the field retain the original 0.8 floor. This narrows the field's pace spread
without rewriting roster ratings or changing vehicle grip, power, assists or physics.
Seeded form, throttle ratings and brake ratings still apply.

Pit exit retains the prior 0.92 cornering utilisation, 0.8 rating floor and 0.8
braking utilisation through optional pit-specific profile fields. Raising these
along with racing pace caused merge contacts in the full-field test. Omitting
the overrides makes a profile inherit its racing settings for pit exit.

Lane changes reserve cornering utilisation at 0.92 from commitment until the car
has returned to its main groove. This is a separate safety allowance for the
passing paths; clean-air pace should not be inferred from laps spent in traffic.
Traffic following also reserves 4.2 m lateral clearance and 0.7 seconds of headway.

`tools/validate_ai_pace.gd` runs 150 simulated seconds at the normal 1/60 s physics
step, seed 1234. Cars start on track at 65 m/s and are ghosted only in this fixture
to isolate driving pace. Actual vehicle integration and ordered timing gates remain
active. It drops the first timed lap and reports five subsequent laps per driver.
The test checks shared player/AI parameters, a valid corridor, repeated laps,
road clearance and a 21.5–23.2 s clean-air pace envelope.

| Group | Mean lap range across drivers |
| --- | --- |
| Front five | 22.293–22.325 s |
| Middle five | 22.397–22.448 s |
| Back five | 22.560–22.589 s |

Maximum road-centre offset was 6.734 m. The two-car, fixed-100-rating reference
ran approximately 22.233 s. These are measured results, not guaranteed lap times
for other seeds or for traffic. Outputs are under `builds/ai_pace_tuned.json`;
`-- --reference` selects the two-car field, and `--capture` adds diagnostic CSVs.

`tools/validate_full_field.gd` separately checks real traffic, pit limits, completed
passes, contacts and the 9 m car-centre road limit over five simulated minutes.
The reference validator now measures that physical road limit rather than its
old 5 m distance-to-target-line limit: tracking the new low target apex produces
a larger target error while remaining within the road.

The final five-minute field run passed: all 15 joined by 114.8 s, 122 passing
attempts, five completed passes, zero contact ticks, zero road-limit violations
and 7.853 m maximum road-centre offset. The slowest join was 207.9 km/h and no
unobstructed committed merge stopped. Actual field best laps were 22.540–23.813 s:
traffic and conservative passing still cost time and can invert the roster order.
This tune establishes raw pace; it does not claim that the racecraft can deliver
each driver's clean-air time while boxed in.

A final standalone 30-second moving-cockpit check with mirrors and all opponents
active averaged 58.6 FPS (17.065 ms mean, 16.638 ms median, 17.587 ms p95,
18.406 ms p99). The 15 AI planners cost 1.264 ms per physics tick. This short
check includes initial frames and is not a guarantee of a locked 60 FPS in the editor.
