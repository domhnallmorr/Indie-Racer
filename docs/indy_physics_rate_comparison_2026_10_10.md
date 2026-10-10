# Indy outer physics cadence: 60 versus 120 Hz

The current player handling changes very little in the recorded corner replay,
but 120 Hz resolves transient wheel loads more accurately. Retain the current
120 Hz default for now. This establishes some suspension value; it does not
establish that running every AI collision/grounding update at 120 Hz is worth
its rendering cost.

## Controlled comparison

`tools/compare_indy_physics_rates.gd` instantiates a fresh Indy private-testing
scene at each of 60, 120 and 240 Hz, with no AI and the optimized road collider.
It restores the recorded corner-entry engine/wheel state, gearing, fuel and
aero setup. Each of the 198 recorded control samples is held for exactly 1/60 s
at every cadence. Position, yaw, speed and corner loads are recorded at common
60 Hz boundaries. Physics time scale is 1: `move_and_slide` and `drive_step`
must use the same delta. Preliminary accelerated runs with mismatched deltas
were discarded and their output overwritten.

The replay lasts 3.3 s. The maximum 60/120 Hz separation is 0.186 m in position,
0.0209 degrees in heading and 0.0165 km/h in longitudinal speed. Final heading
differs by 0.0160 degrees. Every cadence retains suspension support and avoids
chassis floor contact. These are close results for this input sequence, not
proof of equivalent full-lap handling or feel at the grip limit.

An additional 5.667 s prescribed reference-path traversal compares banking
support with steering trajectory differences removed. The horizontal path,
nominal speed state (95 m/s) and controls are imposed; vertical travel remains
active. This is a support test, not a lap replay. All cadences retain support
and avoid chassis floor contact.

| Test | 60 Hz peak corner load | 120 Hz | 240 Hz reference | 60/reference difference | 120/reference difference |
| --- | ---: | ---: | ---: | ---: | ---: |
| Recorded corner controls | 7,945 N | 8,296 N | 8,845 N | 10.17% | 6.21% |
| Prescribed banking traversal | 6,885 N | 7,584 N | 7,716 N | 10.77% | 1.71% |
| Physical 30 mm single-wheel bump | 5,467 N | 5,668 N | 5,803 N | 5.80% | 2.33% |

These are maxima observed at each cadence, not pointwise load errors. The
240 Hz run is a numerical convergence reference, not measured real-car truth.
Lower-rate sampling can miss brief peaks and dips. The prescribed bank minimum
total load is 14,846/11,873/9,918 N at 60/120/240 Hz, so even 120 Hz is not fully
converged for all transient load statistics.

`tools/compare_indy_bump_rates.gd` reuses the existing physical bump scene,
changes both collision and model cadence together, and preserves equal
settling and traversal durations. All three rates excite the correct wheel,
retain support and settle. Peak body roll is 0.522/0.480/0.463 degrees at
60/120/240 Hz; peak heave speed is 0.178/0.164/0.156 m/s.

The separate analytical suspension test still gives 12.3% versus 3.7%
peak-load differences for 60 and 120 Hz versus 240 Hz. Its existing 8% target
is a project accuracy choice, not an experimentally proven perceptibility
threshold. The physical bump and banking results above provide additional
evidence rather than relying solely on that chosen target.

## Performance and decision

The earlier release full-field tests measured 47–48 FPS with the optimized
collider at 120 Hz, and 60 FPS with the original collider at 60 Hz. Those tests
are documented in `indy_practice_profile_2026_10_10.md`. A further optimized
60 Hz release run is saved as `builds/indy_release_reduced_60.json`: 60.03 FPS,
18.431 ms p99, two frames over 33 ms and none over 50 ms in twenty seconds
after ten seconds of warmup. All 20 AI finish grounded, with the player at
315.2 km/h. This run used a 1920x1080 window; the earlier 120 Hz samples used
1920x1009, so it confirms reaching the VSync cap rather than providing an
exact matched-resolution speedup ratio. The initial attempt used a packed
`res://` output path and could not save; the recorded rerun uses an absolute
writable output path and isolated APPDATA.

The tyre/drivetrain integration already uses at most 0.5 ms internal substeps.
The outer-rate benefit demonstrated here comes from more frequent road,
suspension and collision sampling. Dropping globally to 60 Hz sacrifices
measurable load accuracy for small measured handling differences in this short
replay. Keep 120 Hz as the default while targeting the measured AI collision
and grounding costs. A later 60 Hz default needs broader track/contact and
grip-limit comparisons, plus a driving assessment; these fixtures alone do
not justify changing all tracks.

## Verification and reproduction

The rate comparisons, physical bump checks, `validate_suspension_travel.gd`
and `validate_bicycle.gd` pass. `validate_lift_off.gd` fails existing Texas
slide/engine-braking expectations with the current model at both 60 and
120 Hz; its printed paired rate results agree. No runtime model or default
physics setting was changed during this comparison.

Run with the Godot console executable from the project directory:

```powershell
godot --headless --path . --script tools/compare_indy_physics_rates.gd
godot --headless --path . --script tools/compare_indy_bump_rates.gd -- --hz=60
godot --headless --path . --script tools/compare_indy_bump_rates.gd -- --hz=120
godot --headless --path . --script tools/compare_indy_bump_rates.gd -- --hz=240
```

Raw common-time replay samples are in `builds/indy_physics_rates.json`; run logs
are `builds/indy_physics_rates.log` and `builds/indy_bump_{60,120,240}.log`.
Build outputs are ignored by Git. In a restricted workspace, direct APPDATA to
a writable isolated directory as done for the earlier export benchmarks.
