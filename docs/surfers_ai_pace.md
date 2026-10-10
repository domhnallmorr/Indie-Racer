# Surfers Paradise AI pace

The main-line speed reference now comes from the player's 8 October 2026
18:27:45 recording. The selected lap is 95.146 seconds, through all four
ordered timing gates, entirely grounded and on tarmac, outside the pit limiter,
with no recorded wall impacts. A second eligible lap took 95.906 seconds.
The faster 94.860-second lap had off-tarmac samples and was excluded.
Ground contact counts are not wall impact counts; the importer checks the
wall delta-velocity diagnostic instead.

Speeds are projected by position onto the existing AI racing line and smoothed
over approximately six metres. Their integrated reference time is 95.138 s,
with targets from 50.7 to 301.5 km/h. This is a speed reference, not a guarantee
of matching the player's lap: AI acceleration, braking preview, driver strength,
fuel, tyre penalties, traffic and tracking still apply.

The previous 126.022-second generated profile remains as `tactical_speed_mps`.
It constrains cars using alternate lanes, launch offsets or alongside protection.
Clear main-line cars use the player reference. Profiles without this optional
array retain the existing oval planner behaviour. The main-line and tactical
references both receive braking preview so changing line cannot rely on the
player's original braking capability.

The two-car 420-second circulation and pit-service test passed: best laps
103.135 and 105.081 s, maximum tracking error 1.234 m, zero wall/car contact
ticks, and successful service/rejoin. Planner cadence regression also passed.
The final 20-car, immediate-green 420-second stress test completed timed laps
for every driver with zero contact ticks, but failed the existing 3 m tracking
threshold (maximum 3.788 m). Several cars remained in slow traffic queues;
their best laps were 126.7–139.7 s while most others ran 103.2–105.5 s.
An old-profile 120-second comparison also failed tracking (maximum 3.576 m),
confirming a similar pack-tracking issue exists with the conservative profile.
That short comparison is not a lap-pace validation: no complete timed laps
were expected within its duration. The full-field test is not a clean pass.

To audit available local player recordings:

```powershell
python tools/audit_surfers_telemetry.py
```

To rebuild from the selected recording, or another F11 run:

```powershell
python tools/build_icr2_profile.py --track surfers_paradise --telemetry "$env:APPDATA/Godot/app_userdata/Oval Racer/telemetry/practice_2026-10-08T18-27-45_13800.csv"
```

Rebuilding track geometry with `build_surfers_paradise.py` regenerates the
conservative profile by default; reimport the player reference afterwards.
For scenery-only edits, pass `--geometry-only` to preserve the current AI
profile and session configuration without needing to reimport. Recordings
are not bundled. The profile retains the source hash and selected CSV row range.

This change establishes pace. Corner-specific outbraking, inside defence,
overlap decisions, and different exit costs still need a dedicated racecraft
plan. Tactical speeds currently use the conservative all-lane envelope rather
than separate optimised speeds for each attack/defence line.

The later second-chicane geometry revision adds a local override: the 630–770 m
road and racing path now bend around a deeper grass island. The old telemetry
speeds cannot be used unchanged there. The active profile caps that corner's
main-line target to approximately 74 km/h and carries the resulting braking
and acceleration ramps into its approach and exit. Elsewhere the measured pace
is retained. `second_chicane_speed_baseline` preserves the prior speed arrays;
`layout_adjustment` records the reason. The source recording and measured lap
time describe the previous layout, while `reference_lap_s` is recomputed for
the revised path/speeds. Use the track builder's `--update-second-chicane` mode
to reproduce this local edit without resetting the rest of the pace profile.
