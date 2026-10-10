# Indy practice profiler capture — 10 October 2026

Inspected the user's retained Godot 4.7.2 editor profiler through Windows
computer control. No gameplay settings or source code were changed.

The latest frame report, `frame_times_2026-10-10T15-55-11_292693.json` in
the Oval Racer user telemetry directory, records Indianapolis practice,
20 AI, seed 1326195860, and 15,739 frames. Mean interval is 17.770 ms;
245 frames exceed 33.333 ms and three exceed 50 ms. The latest 128 retained
slow frames average 8.026 ms on the periodic physics monitor. Most contain
four or more physics ticks. Current project physics frequency is 120 Hz.

## Retained profiler samples

The profiler uses Frame Time (ms). These are manually transcribed displayed
values, not an exported profiler dataset. Calls span all physics ticks in
the selected rendered frame. Inclusive values overlap and must not be added.

At frame 16081:

| Entry | Inclusive ms | Self ms | Calls |
| --- | ---: | ---: | ---: |
| Script Functions | 38.49 | — | — |
| AI `_physics_process` | 34.86 | 0.26 | 120 |
| `reference_step` | 27.56 | 0.93 | 120 |
| `_move_with_car_contacts` | 21.42 | 10.62 | 126 |
| `_try_surface_step` | 10.56 | 10.51 | 120 |
| Player `_physics_process` | 5.83 | 0.00 | 6 |
| `drive_step` | 5.70 | 0.10 | 6 |
| `_update_visual_grounding` | 3.05 | 2.98 | 120 |

The player call count and 120 AI calls indicate six physics ticks for the
20-car field in that rendered frame. Physics Time reads 8.49 ms, Physics 3D
0.58 ms, and Process Time 6.96 ms. The Physics Frame Time entry of 8.33 ms
corresponds to the configured 120 Hz interval; it is not the script total.

At frame 15971, Script Functions reads 22.86 ms. There are four player
updates, 80 AI updates and 84 movement calls. `_try_surface_step` consumes
5.84 ms self time, and visual grounding 1.74 ms self time. This corroborates
the collision/query-heavy work across another multi-tick frame.

The visible Errors tab entries were startup GDScript warnings (integer
division, shadowed names, type conversions). No evidence of a repeated
runtime error causing these samples was found in the inspected rows.

## Interpretation and next measurement

Vehicle movement and surface-step collision queries are the strongest
measured optimization targets. Their combined self time in frame 16081 is
21.13 ms, about 55% of that frame's reported script total. This does not
imply car-to-car crashes: movement includes normal road/body collision
queries and engine movement calls. The engine's Physics 3D category alone
does not capture all queries invoked from scripts.

120 Hz increases simulation work per wall-clock second. These samples show
accumulated multi-tick costs, but do not establish which event initially
delayed rendering. Rendering/presentation and profiler overhead remain
possible contributors. Editor timings are not release-export timings.

## Implemented collider optimization

`content/tracks/indianapolis/road_collision.gd` replaces eight-quad strips
with two triangles only when all source vertices have exactly the same
height, both cross-track edges are straight within 0.1 mm, and the original
area and winding agree. Unexpected layouts retain the original triangles.
The corners are taken from the actual runtime collision mesh. Repeated
application leaves the installed collider unchanged.

450 level strips qualify. The road collider falls from 32,192 to 25,892
triangles (19.6% fewer). All 18,910 banked/transition triangles remain exact.
Visual geometry, apron, pit road, barriers, physics frequency and car counts
are unchanged. Only the Indy road setup opts into this helper.

## Follow-up on contact fixture failures

The later [physics-rate follow-up](physics_rate_followup_2026_10_10.md) matches
the contact fixtures' hard-coded model step to the engine collision tick.
Those adapted fixtures pass at 60/120/240 Hz. The earlier failures above remain
an accurate record of the unchanged tests, but their timestep mismatch means
they are not confirmed runtime contact regressions.

## Release export comparison

Used the installed Godot 4.7.2 Windows release template, GL Compatibility,
1920x1009 maximized window, normal cockpit/mirrors/shadows, VSync, 20 AI and
seed 1326195860. The repeatable practice fixture deploys the AI 150 m apart
at 85 m/s, disables their practice/pit cycles and incidents, and drives the
actual player controller using an oval-driver pilot. It warms up for ten
simulation seconds and samples twenty simulation seconds. This is a
controlled full-field workload, not a replay of the user's laps or natural
practice departures. It does not change normal game behaviour.

No editor profiler, timing wrappers, fixed-FPS option or concurrent benchmarks
were used in the release comparisons. Runs were sequential in original /
reduced / reduced / original order, followed by the original collider at
60 Hz. `--original-road` regenerates the original collider from the same
visible road mesh. Each result contains run settings and final car poses.

| Release case | Mean FPS | p99 frame ms | Frames >33.333 ms | Frames >50 ms |
| --- | ---: | ---: | ---: | ---: |
| Original, 120 Hz, A | 36.84 | 43.556 | 122 | 0 |
| Reduced, 120 Hz, A | 47.35 | 35.038 | 30 | 0 |
| Reduced, 120 Hz, B | 48.29 | 40.206 | 40 | 0 |
| Original, 120 Hz, B | 34.64 | 55.303 | 167 | 18 |
| Original, 60 Hz diagnostic | 60.03 | 18.117 | 0 | 0 |

The two reduced-collider runs averaged about one-third higher FPS. Across
the two 120 Hz runs per variant, frames exceeding 33.333 ms fell from 289
to 70. All 20 AI were grounded at the final checkpoints; average AI speed
was about 97.35 m/s in all four 120 Hz runs, and the player remained moving
at about 315 km/h. Sample lengths differ by at most one physics tick.

The improvement repeats, but does not establish stable 60 FPS or identical
long-term racing trajectories. 120 Hz remains the project setting. The
60 Hz result is a diagnostic and requires separate handling/suspension
verification before becoming a gameplay change. Banked-road query costs
and combined simulation/render submission pressure remain next targets.

Raw results are `builds/indy_release_{original,reduced}_120_{a,b}.json` and
`builds/indy_release_original_60.json`. The test build is
`builds/indy_perf/indy_perf.exe` with its adjacent `.pck`.

Earlier instrumented runs mistakenly left the automated player in its
pit-stop brake state, causing a queue. They are retained for transparency
under `indy_practice_baseline_*` / `indy_practice_collider_120` but are not
used for the conclusions above. After correcting that fixture, initial
editor-binary runs measured 25.29 versus 35.74 FPS at 120 Hz; the release
comparisons supersede those preliminary timing estimates.

## Validation

- `validate_indy_road_collision.gd`: 40,240 rays at all source triangle
  centroids and just inside/outside strip boundaries; same coverage and
  normals, maximum support-position difference 0.00000002980232 m.
  All banked faces, incomplete-layout fallback and idempotence checked.
- `validate_indy_travel.gd`: passed real road support, parked banking,
  wheel stance, freefall/landing, transitions and telemetry.
- `validate_indy_corner_support.gd`: passed continuous heave, bank
  clearance, tyre loads and recorded corner driving with no lost support.
- `validate_surface_step_equivalence.gd -- --track=indianapolis`: passed
  229,320 comparisons with zero mismatches. This compares the installed
  surface-step algorithm to its original four-candidate solver on the
  current collider, not to the previous collision topology.
- The existing Mile Oval `validate_car_contacts.gd` and
  `validate_wall_contacts.gd` fail in the current working tree. Repeated
  them with the new Indy collider setup disabled: both fail with the same
  failure messages. These tests do not load Indy. Their failures include
  player momentum/separation and banked Mile wall fixtures; they remain
  outside this change. Logs are `builds/*_baseline_indy_perf.log` and
  `builds/*_indy_perf.log`.

Some tests/exported runs retain existing ObjectDB leak warnings on exit.
The first export attempt hit sandbox configuration-save errors. A later
export using writable APPDATA/TEMP produced a working packed project and
passed the release smoke test and all five benchmark runs. The exporter
still emits an editor safe-save warning; no security settings were changed.

## Reproduce

Run one benchmark at a time. The default output is
`user://telemetry/indy_practice_profile.json`; use distinct `--output=` paths
to retain successive results. APPDATA isolation can keep benchmark telemetry
separate from normal play.

Editor binary:

```powershell
godot --path . --maximized res://tools/profile_indy_practice.tscn -- --hz=120 --seconds=20 --moving-player
```

Release export:

```powershell
.\builds\indy_perf\indy_perf.exe --maximized -- --profile-indy --hz=120 --seconds=20 --moving-player
```

Add `--original-road` for the baseline or `--hz=60` for the rate diagnostic.
The explicit menu entry argument is needed because this release template
rejects command-line scene-path overrides. Normal menu launches are unchanged.
