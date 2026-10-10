# Performance investigation

## Indianapolis practice at 120 Hz (10 October)

Reducing only verified level road collision strips removes 6,300 of Indy's
32,192 road triangles while preserving all banked faces and the visual mesh.
Two sequential Windows release comparisons measured 34.64–36.84 FPS with the
original collider and 47.35–48.29 FPS with the reduced collider. The deployed
20-car fixture uses a moving cockpit player, normal mirrors/shadows and VSync
at 1920x1009. Physics remains 120 Hz. A 60 Hz diagnostic held 60 FPS, but was
not adopted as a gameplay change. This optimization helps; it does not yet
deliver stable 60 FPS at 120 Hz.

Road support, bank/corner clearance and surface-step equivalence checks pass.
Older Mile Oval contact fixtures fail identically with and without this Indy
change. See [the full report](indy_practice_profile_2026_10_10.md) for controls,
raw results, limitations and the repeatable exported-game benchmark.

The [60/120/240 Hz player comparison](indy_physics_rate_comparison_2026_10_10.md)
finds very close short corner-replay handling, but more accurate transient
wheel loads at 120 Hz. The current default remains 120 Hz; global 60 Hz has
not been accepted from these limited fixtures.

The [full-lap/contact/AI follow-up](physics_rate_followup_2026_10_10.md) confirms
that Indy fixed-input trajectories diverge over a lap even though pilots at
both rates complete it with similar timings. Matched-timestep contact fixtures
pass at 60/120/240 Hz. Instrumented AI contact movement and surface-step
attempts dominate planner cost, making them the next optimization target.

## Mile Oval road collider (4 October)

`content/tracks/mile_oval/surface/road_collision.gd` simplifies the imported road
collider once at scene load. Each level rectangular strip uses two triangles
instead of 40. The current road falls from 32,200 to 16,658 collision triangles
(48.3% fewer), with 409 strips simplified. All banked and transition triangles
are copied exactly. The visual mesh, apron, pit lane and barriers retain their
imported geometry; movement, stepping and grounding remain at 60 Hz.

The helper uses the collider's existing vertices, rather than reconstructing it
from reference paths or mesh vertices. Godot's imported collision vertices have
slightly different rounding, and reconstruction changed step decisions in the
initial trial. Rectangle corners, area and winding are checked before replacement;
unexpected strip layouts retain the original detail. No separate baked collision
asset is needed after a GLB reexport.

`tools/validate_mile_road_collision.gd` checked 32,208 support rays, including every
original triangle centroid and both sides of the straight road edges. Heights,
normals and coverage matched exactly, and all 15,759 sloped triangles survived
unchanged. Car contacts, wall contacts, visual grounding, surface reentry and
road/pit route validation also passed.

Four headless 20-car, seed-42 live starts ran in original/simplified/simplified/
original order, measuring 20 seconds after green. Both variants stayed grounded
and reported no false wall impacts from the road. Repeated runs of each variant
had identical position/speed checkpoints. Changing the triangle topology causes
small physics differences: the largest original/simplified checkpoint separation
was 0.056 m, and the largest speed difference was 0.0192 m/s. This is a short
racing fixture rather than a guarantee of identical long-term race outcomes.

Live timing varied substantially between runs, including unrelated planner and
tow costs, so their percentage differences are not used as an isolated gain.
The installed collider's controlled 8,000-pose surface-step replay measured 2.61
to 1.81 ms per 20-car field tick (30.4% less step-query CPU work), using warm-up
batches and alternating ABBA order. Step results matched exactly at every pose.
Raw results are in `builds/surface_step_review/mile_oval_mesh_implementation.json`;
the live-run summary is `builds/surface_step_review/implementation_live_summary.json`.
Headless query timings do not measure rendered FPS.

For a repeatable live comparison, run `tools/profile_texas_start.gd` with
`-- --track=mile_oval --seconds=20 --seed=42 --instrument`, then add
`--original-road-collider` to restore the original imported road for the baseline.
That diagnostic option preserves the rest of the scene and writes a separate
`_original_road` result file. Run benchmarks sequentially.

## GPU utilisation during the Mile Oval test (3 October)

Sampled the RTX 4060 Ti 16 GB with NVIDIA's `nvidia-smi` at one-second intervals
while running the normal rendered isolation case (20 AI, mirror and shadows,
1920x1009, VSync enabled). The profiler now saves its sampling start Unix time
so the GPU CSV can be trimmed to the same 60-second measured window rather than
including loading, formation or idle time. All 60 matching samples were used.

| Device-wide metric | Mean | Range |
| --- | --- | --- |
| GPU utilisation | 46.7% | 8–69% |
| Memory-controller utilisation | 13.2% | 1–26% |
| Allocated VRAM | 1,757 MiB | 1,746–1,759 MiB |
| GPU power | 20.3 W | 16.6–38.3 W |
| Graphics clock | 611 MHz | 285–2,595 MHz |
| Memory clock | 1,063 MHz | 405–9,001 MHz |
| Temperature | 42.4 C | 41–44 C |

Reported board power limit was 165 W and VRAM capacity 16,380 MiB. During this
same run the game averaged 56.09 FPS, with 58 frames above 33.333 ms, 12 above
50 ms, p99 34.665 ms and a 74.141 ms worst frame. The normal rendering workload
therefore still stuttered without sustained whole-GPU saturation or VRAM pressure.

Utilisation is device-wide, not per-process, and averages over sampling windows;
it cannot rule out brief fully busy intervals or identify each hitch's cause.
It also measures activity at the current clock, not a percentage of maximum
boost-clock throughput. Clocks/power remained low for much of this VSync-limited
test, with occasional boost. That can reflect a GPU waiting for CPU/driver work
or presentation, but the data does not exclude power-state/clock-transition
effects. No driver power-management settings were changed. A post-run idle P8
snapshot must not be interpreted as the GPU state throughout gameplay.

The rendering-isolation result should thus be read as CPU/GPU rendering-path
overhead on top of simulation, not proof that this GPU lacks rendering capacity.
CPU draw submission/driver timing and GPU render times/power-state behaviour are
the next distinctions to measure before selecting a graphics optimization.
Raw results: `builds/mile_gpu_sample_frames.json`,
`builds/mile_gpu_utilization_samples.csv`, and
`builds/mile_gpu_utilization_summary.json`. The earlier isolation baseline JSON
was preserved after this follow-up run.

## Simulation/rendering isolation (3 October)

`tools/profile_mile_isolation.gd` isolates the recorded Mile Oval stationary
cockpit scenario: seed 1181179623, 20 AI, current 15/30 Hz planning trial,
1920x1009 maximised window, normal mirror, and VSync enabled. Live cases begin
sampling three seconds after green (one second before applying the diagnostic
change plus two seconds to settle). They sample 60 wall-clock seconds. No
`--fixed-fps` is used and no benchmarks run concurrently.

| Case | Sample | Mean FPS | p99 frame | Frames >33.333 ms | Frames >50 ms | Median draw calls | Median physics monitor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Normal live scene | 60 s | 56.42 | 34.576 ms | 52 | 12 | 4,700 | 10.921 ms |
| Live simulation, 3D drawing disabled | 60 s | 59.99 | 19.175 ms | 1 | 0 | 59 | 10.723 ms |
| Live scene, sun shadows disabled | 60 s | 58.67 | 32.510 ms | 27 | 10 | 2,061 | 10.750 ms |
| Frozen full scene at 30 s after green | 30 s | 60.00 | 16.980 ms | 0 | 0 | 3,567 | 0.061 ms |
| Frozen busy full scene at 14 s after green | 20 s | 60.00 | 16.977 ms | 0 | 0 | 5,607 | 0.080 ms |

The minimal-render case sets `disable_3d` on the main and subviewports; all
gameplay callbacks, collision shapes, AI, physics, HUD and telemetry remain
active. The sampled driver advanced 60.017 simulation seconds. Overlapping
telemetry rows matched for all 16 normal-run AI CSVs still retained when checked
against the minimal-render run (repeated launches can reuse the existing AI
logger's millisecond-based filenames). This is a rendering diagnostic, not a
gameplay configuration or a proposed blank-screen fix.

Frozen cases disable scene process/physics callbacks and the 3D physics server,
while retaining mesh visibility, lights, shadows, cameras and viewport update
modes. All 20 car transforms and driver elapsed times were checked unchanged.
The second snapshot was selected near the normal run's busiest recorded view
(about 5,750 draw calls around 13.7 seconds after green), to avoid relying only
on the easier 30-second snapshot. Freezing also removes HUD/game callback work;
these are not isolated GPU timer measurements.

The evidence points to combined simulation/rendering pressure. Removing 3D
drawing nearly eliminated slow frames while keeping the simulation running;
removing simulation left even the busy rendered snapshot smooth. Removing just
sun shadows more than halved median draw calls and reduced the observed slow
frames from 52 to 27. This makes shadow/mirror passes and scene draw submission
a stronger next optimization target than further small planning-rate changes.
It does not distinguish CPU render submission/driver overhead from GPU work,
nor prove that every hitch has the same cause. Physics monitors are periodic
snapshots, and sequential single runs do not establish a precise percentage
improvement across sessions.

Only diagnostic tooling and this report were changed for the isolation work;
the game's normal shadows, mirror and simulation remain enabled. Run Godot
with `--maximized --script tools/profile_mile_isolation.gd -- --case=live_full`,
or `--case=live_minimal`, `--case=live_no_shadows`, or
`--case=frozen_full --seconds=20 --freeze-at=14`. Use an isolated writable
APPDATA directory for telemetry. Per-case JSON and a combined report are saved
under `builds/mile_isolation_*.json` and `builds/mile_isolation_summary.json`.

## Mile Oval speed/steering planning trial (3 October)

Mile Oval's `ai/profiles.json` opts the reference AI into 15 Hz speed planning
and 30 Hz steering-path sampling. Other tracks default to 60/60 Hz. The shared
physics-frame clock and existing per-car phases stagger these calls. Steering
curvature blends between sampled commands over the steering interval; speed
commands still pass through the car's 60 Hz acceleration/braking integration.
Traffic assessment remains at its existing 15 Hz. Movement, collisions, route
index tracking, slipstream and visual grounding remain at 60 Hz.

Pit manoeuvres run full-rate. Mode/ghost changes immediately refresh both plans.
While racing, an opponent within 20 m longitudinally and 4 m laterally in the
existing traffic snapshot restores 60 Hz planning. This guard can substantially
reduce savings in a tightly packed field; 15/30 Hz are clear-running rates, not
unconditional per-car rates. No extra opponent projections are used by the guard.

The cadence/interpolation regression passes all four phases, close-traffic and
pit overrides, mode/ghost invalidation and the 60 Hz comparison mode. The Mile
Oval opening-minute test (20 AI, seed 1181179623) passed with zero contacts,
zero road-offset violations, maximum offset 8.084 m and six completed passes.
Texas pit-exit/contact-recovery checks passed. A global 15/30 Hz trial failed
the Texas opening-minute contact check (one contact without the close-traffic
guard, five with it); therefore Texas was not opted into the lower rates.
The final Texas 60/60 Hz run passed with zero contacts, zero road-offset
violations and maximum offset 8.132 m.

The profiler accepts `--speed-hz=60 --steering-hz=60` for a full-rate comparison;
omitting those flags uses the track's configured rates. The ordinary bicycle
AI controller does not use this reference-driver planning scheduler.

Sequential rendered comparisons used the recorded parked position, seed
1181179623, 20 AI, a maximised 1920x1009 window, normal mirror rendering and
telemetry. Each samples approximately 59 seconds after the post-green warmup:

| Planning | Mean frame | p99 | Frames >33.333 ms | Frames >50 ms | Minimum FPS | Median physics |
| --- | --- | --- | --- | --- | --- | --- |
| Trial 15/30 Hz with proximity override | 18.004 ms | 35.435 ms | 65 | 13 | 24 | 11.424 ms |
| Fresh 60/60 Hz comparison | 18.170 ms | 42.597 ms | 87 | 16 | 24 | 11.637 ms |

This pair suggests fewer slow frames, but average frame time changes by less
than 1% and the minimum counter FPS is unchanged. It does not establish a cure
or a repeatable 25% hitch reduction. Racing trajectories differ between rates,
and longer-session behaviour remains unverified. Raw results are
`builds/mile_oval_planning_15_30.json` and `builds/mile_oval_planning_60_60.json`.

## Surface-step optimization (3 October)

`basic_car.gd` now stops the surface-step search when an upward clearance sweep
hits an obstacle that does not qualify for the existing drivable-road overlap
exception. Every larger candidate traverses that same blocked vertical segment;
repeating the lift cannot clear it. It also stops after a clear forward sweep
and a landing at/below current height when both the current and landing floor
normals are exactly vertical. Banks retain all candidates: their recovery can
produce a different landing at larger heights. Forward clearance, landing
checks, candidate heights, contact response and simulation rates remain
unchanged. This shared helper also applies to Texas.

`tools/validate_surface_step_equivalence.gd` retains the previous step solver as
a test oracle, runs it at each live AI pose, restores the pose and compares the
optimized result. Formation plus the first 60 seconds after green passed with
110,229 comparisons on Mile Oval and 112,678 on Texas, with zero mismatches.
Car-contact, wall-contact and visual-grounding regressions also passed.
The existing Texas surface-contact fixture failed both before and after this
change: its recorded road-edge ray no longer resolves to the expected face and
its old spurious-wall-response case no longer reproduces. The separate captured
seam-stall case retained 103.485 m/s and travelled 1.733 m on both versions.
The equivalence runs report existing shutdown ObjectDB leak warnings.

The initial blocked-lift-only version had a small measured saving: a fresh
headless baseline measured 2.814 ms/field tick in surface stepping, versus
2.742 ms with that early exit. This is much smaller than a comparison against
the earlier 4.327 ms baseline would suggest; unrelated functions also became
faster between those older and newer runs, so that older baseline is unsuitable
for estimating the optimization gain. Raw results:
`builds/mile_oval_step_baseline_recheck.json` and
`builds/mile_oval_step_optimized_instrument.json`.

The final version (both early exits) was tested with the same parked pose,
seed, 20 AI and normal mirror-active cockpit used below. It measured 18.048 ms
mean, 30.620 ms p95, 35.658 ms p99, 73.330 ms worst, 77 frames above 33.333 ms
and 12 above 50 ms. Minimum counter FPS remained 24; median physics was
11.786 ms. All 20 AI CSVs were byte-identical to the pre-change rendered runs.
Their 88–111 slow frames and 42.625–48.120 ms p99 were worse, but the change is
modest and these sequential runs cannot eliminate system/run variance. This
does not resolve the stutter or demonstrate a substantial simulation saving.
Raw final result: `builds/mile_oval_step_level_render.json`. Mirror rendering
and physics/traffic frequencies were left unchanged.

## Mile Oval parked-player investigation (3 October)

The user's `frame_times_2026-10-03T14-02-38_1119321.json` recorded 3,894
frames over 73.499 seconds: 18.875 ms mean, 29 FPS minimum, 120 frames above
33.333 ms, none above 50 ms, and a 47.742 ms worst frame. Of those slow frames,
116 contained two physics ticks. Physics monitor snapshots averaged 14.615 ms
on those frames; these snapshots cannot identify the initial cause of a hitch.

15 Hz traffic is shared by both AI controllers, including Mile Oval. No track
override exists. Movement, surface stepping, grounding and slipstream still run
at 60 Hz. Reducing traffic frequency therefore does not reduce those costs.

Reproduction used seed 1181179623, 20 AI, a maximised 1920x1009 window and the
recorded stationary player pose (track-local 141.00145, -0.09958, -89.36896;
heading 75.69587 degrees). The profiler parks the player immediately, rather
than replaying the original formation-lap driving or camera switches. Three
sequential rendered runs sampled approximately 59 seconds after a one-second
post-green warmup, with player and AI telemetry enabled. User settings were
copied to an isolated workspace APPDATA directory. No other benchmark ran
concurrently. The normal cockpit and its virtual mirror were used except in
the explicitly disabled-mirror comparison.

| Run | Mean frame | p95 | p99 | Worst | Frames >33.333 ms | Frames >50 ms | Minimum counter FPS | Median physics |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Normal cockpit | 18.558 ms | 32.060 ms | 48.120 ms | 145.537 ms | 111 | 27 | 19 | 11.434 ms |
| Mirror rendering disabled | 17.322 ms | 19.097 ms | 34.205 ms | 68.578 ms | 44 | 12 | 26 | 11.542 ms |
| Normal cockpit repeat | 18.204 ms | 30.905 ms | 42.625 ms | 68.220 ms | 88 | 18 | 24 | 11.650 ms |

Each car's AI CSV hash matched across all three runs (20 of 20 cars), confirming
identical recorded AI behaviour. Disabling mirror rendering reduced slow-frame
counts by 50–60% relative to the normal runs, but substantial hitches remained.
This supports a rendering contribution on top of simulation load, not an
isolated GPU diagnosis or a claim that the mirror is the only cause. There is
only one disabled-mirror sample; the magnitude remains subject to run variance.

A separate headless, fixed-60-FPS instrumented run with the same seed and 60
seconds after green measured field-wide costs per physics tick:

| Measured work | Mean cost |
| --- | --- |
| All AI driver work | 14.554 ms |
| AI movement | 10.702 ms |
| Contact movement, inside AI movement | 9.290 ms |
| Surface-step checks, inside contact movement | 4.327 ms |
| Visual grounding, inside AI movement | 0.897 ms |
| Slipstream update | 0.885 ms |
| Racecraft assessment | 0.792 ms |
| Traffic-speed queries | 0.472 ms |
| Speed planner | 0.344 ms |

These are nested timings and must not be added together. Instrumentation adds
overhead; the headless run parked in the pit box and telemetry was unavailable
because its initial user-data location was not writable. Its frame intervals
are not displayed FPS and its absolute costs should not be directly compared
with the rendered runs. Nonetheless, movement/contact work clearly dominates
the measured AI work, rather than the 15 Hz traffic assessment.

The next simulation optimization target is `basic_car.gd`'s collision movement
and `_try_surface_step`: the latter performs an initial motion sweep followed
by up to four lift/forward/landing candidate checks. Preserve the seam-stall,
wall-contact and banking behaviour while reducing redundant sweeps. Disabling
surface stepping or reducing movement frequency is not a validated fix. Mirror
scene complexity is a separate rendering target; the game defaults were not
changed by this investigation.

Raw combined results: `builds/mile_oval_parked_investigation.json`. Reproduce with
`tools/profile_texas_start.gd -- --track=mile_oval --seed=1181179623 --seconds=60
--park-at=141.00145,-0.09958,-89.36896,75.69587`, passing Godot `--maximized`.
Add `--no-mirrors` for the render comparison. The profiler records both options
and uses distinct parked/mirror-disabled output suffixes. Use isolated APPDATA
for writable telemetry; omit `--fixed-fps` in rendered frame-rate tests.

## 15 Hz traffic trial (3 October)

Traffic assessment and traffic-speed queries now default to 15 Hz. The scheduler
derives the tick interval from the selected rate (15/30/60 Hz), using the shared
physics-frame counter so waiting or pit service cannot shift one car's phase.
Session spawning assigns consecutive phases, distributing 18 AI as 5/5/4/4 over
four 60 Hz physics ticks (the current 20-car AI field uses 5/5/5/5).
First updates and mode/ghost changes still refresh
immediately and can temporarily exceed those group sizes. Movement and steering
remain at 60 Hz. The profiler accepts `--traffic-hz=15` for this trial.

Cadence and elapsed-time checks passed at all three rates. Stopped/slower-car
and hard-braking scenarios passed at all four 15 Hz phases. The smallest
hard-braking origin separation fell from about 9 m at 30 Hz to 7.426 m at 15 Hz,
still above the test's 4.35 m bumper-contact threshold. The slower response is
a real behaviour change, and longer races remain useful follow-up testing.
The full-field Texas opening-minute regression also passed: zero car contacts,
zero road-offset violations, maximum offset 8.132 m and 52 passing attempts.
No completed passes were counted in that minute, though sustained passing lanes
were used. Godot reported the existing four-instance shutdown leak warning.
The older 2 October input replay is no longer a valid performance comparison
with the current roster/game state: it diverged by 871.8 m and ended essentially
stopped. Its frame-rate numbers are excluded from performance conclusions.
Instead, a fresh 30-second automated moving-cockpit run with the current 20 AI,
seed 42, maximised 1920x1009 window and telemetry enabled averaged 16.891 ms
(59.2 FPS), p95 17.906 ms, p99 29.723 ms and worst 43.386 ms. Three frames
exceeded 33.333 ms; none exceeded 50 ms. Minimum counter reading was 49 FPS.
The player completed one lap and ended at 295.1 km/h. This is a short functional
performance check, not a controlled improvement estimate against the older field.

## 30 Hz traffic experiment (2 October)

Both AI controllers now update racecraft assessment and traffic-speed queries
every other 60 Hz physics tick by default. A stable car-name phase staggers the
field. Vehicle integration, steering/path following, slipstream and collision
exclusion maintenance remain at 60 Hz. The most recent traffic cap is reused on
the intervening tick, always respecting a lower current speed plan. Mode/ghost
changes refresh immediately and race-control limits are still applied each tick.
Elapsed time is accumulated for racecraft timers, so changing decision frequency
does not double cooldowns, lane transitions or launch timing. Decisions can react
one physics tick later. Formation traffic is also sampled at 30 Hz; pit departure
and merge-clearance gates remain on their existing physics update path.

`traffic_update_hz = 60` restores full-rate traffic. The start profiler accepts
`--traffic-hz=30` or `--traffic-hz=60` and reports the selected rate. Instrumented
costs are normalized to vehicle physics ticks even when racecraft runs less often.

Using the same maximised Texas replay, seed 953509344, 18 AI and 60 seconds after
green, the 30 Hz run averaged 16.738 ms/frame (59.7 FPS), p95 17.968 ms, p99
19.303 ms, worst 41.846 ms, with four frames above 33.333 ms and none above 50 ms.
The counter's minimum was 54 FPS; median physics time was 10.931 ms. The previous
60 Hz run measured 17.307 ms mean, 32.672 ms p99, 25 frames above 33.333 ms and
a minimum counter reading of 41 FPS. These are sequential runs, not a guarantee
of all-session performance. Traffic decisions and tow interactions now differ:
the replay's maximum position difference was 5.655 m, rather than the previous
bit-identical path. Final player speed was 373.190 km/h.

Validation passed: cadence/staggering and elapsed-time accounting; immediate mode
and ghost refresh; stopped/slower/hard-braking cars at both 30 Hz phases (minimum
origin separation at least 9 m); pit-contact transitions; and caution rules.
The full-field Texas opening minute produced three completed passes, zero car
contacts and zero >9 m road-offset ticks (maximum offset 8.116 m). The Texas
validator still reports an ObjectDB shutdown leak warning. Other tracks and
longer sessions have not yet received a full 30 Hz soak test.

## Recorded Texas race: 28 FPS dip (2 October)

The player's saved report `frame_times_2026-10-02T17-47-31_110832.json` confirms
a minimum counter reading of 28 FPS in a 1920x1009 maximised cockpit session.
Across 3,568 frames (65.203 seconds), mean frame time was 18.275 ms; 76 frames
exceeded 33.333 ms, none exceeded 50 ms, and the worst was 49.155 ms. Several
long frames at 25 and 48 seconds contained three physics updates between renders.
The physics monitor snapshots were around 15 ms there; these are consistent with
limited simulation headroom and catch-up, not proof of an isolated CPU/GPU cause.
The car reached 360–372 km/h, faster than the previous route-driver fixture.

The start profiler now accepts `--seed=<integer>` and `--replay=<player CSV>`.
Replay supplies recorded pedals/steering to the real player physics, with the
current setup and seeded race, and reports maximum position error against the
recording. It does not teleport the car. Setup/software changes can invalidate
replays; check the error before comparing performance. This recording and seed
953509344 reproduced all 5,687 sampled player positions exactly (zero error).
The 60-second headless instrumented run attributed 8.81 ms/field tick to AI
movement (including 3.90 ms surface stepping), 3.69 ms to racecraft, 1.32 ms to
slipstream and 0.225 ms to collision-exclusion maintenance. These nested costs
overlap and instrumentation adds overhead; they are not displayed frame times.

Slipstream sampling now rejects distant cars before detailed eligibility checks
and reuses the follower's transform/speed during a query. Collision exclusions
are applied only when a pair's combined ghost state changes, preserving overlap
checks and reciprocal exclusions. The slipstream/dirty-air regression and Michigan
pit-contact regression pass, including repeated states and both driver update
orders through one-car and two-car ghost transitions.

One sequential maximised rendered before/after pair, 60 seconds after green:

| Query implementation | Mean frame | p95 | p99 | Worst | Frames >33.333 ms | Median physics |
| --- | --- | --- | --- | --- | --- | --- |
| Before | 17.589 ms | 28.817 ms | 33.328 ms | 50.873 ms | 33 | 12.553 ms |
| After | 17.307 ms | 18.655 ms | 32.672 ms | 46.575 ms | 25 | 12.110 ms |

Both replays had zero player position error, identical final speed (373.263 km/h)
and tow-tick count (29,275). The normal HUD reports, which also include the first
second after green, recorded minimum counter readings of 38 and 41 FPS. This
pair suggests improved headroom but is not a guarantee against the original
28 FPS dip or all stutters. The original user's 28 FPS reading remains distinct
from these replay results. Logs: `tmp/texas_replay_before.log` and
`tmp/texas_replay_after.log`; preserved baseline JSON:
`builds/texas_replay_before_query_optimization.json`.

## Maximised-window follow-up and normal-session diagnostics (2 October)

The user confirmed a separate maximised game window. Repeating the 60-second
moving-cockpit Texas fixture with `--maximized` produced a 1920x1009 client window
(1370x720 logical viewport), 18 AI and all telemetry enabled. Mean frame time was
17.463 ms (57.3 FPS), p95 27.208 ms, p99 33.252 ms, worst 46.930 ms, with 32 frames
above 33.333 ms and none above 50 ms. Two player laps completed with the same
progress as the smaller-window runs. This still does not reproduce the 17 FPS
counter reading. The profiler now records window mode, client size and logical
viewport size, and gives maximised results a separate `_maximized.json` suffix.

The normal HUD FPS counter now records frame diagnostics during running sessions.
It keeps aggregate frame counts, mean/worst frame time, minimum displayed engine
FPS, and the latest 128 frames above 33.333 ms. Each hitch includes camera, player
speed/position, window mode/size, physics-tick count between renders, and engine
physics/draw-call monitor snapshots. Those monitors are not isolated timings for
the hitch and should be interpreted alongside the frame interval. No diagnostic
file I/O occurs while driving; leaving the scene or normal game shutdown saves
`user://telemetry/frame_times_<timestamp>_<ticks>.json` and prints its path.
Forced process termination cannot save the in-memory report. Headless runs skip
this capture. `tools/validate_frame_diagnostics.gd` runs with a renderer and checks
exact counts using injected timestamps, bounded history, camera context,
inactive-time exclusion and shutdown-only writes; it passed. The existing AI
logging integration test also passed (with its existing shutdown leak warning).

## Texas cockpit stutters: telemetry flush bursts (2 October)

The ICR2 controller used by Texas bypassed the bicycle controller's buffered,
staggered telemetry writer. All 18 opponents started the same one-second flush
timer at green, issuing synchronous disk flushes together on the physics thread.
It now buffers the existing 10 Hz diagnostic rows and offsets each car's flush
timer by its name hash. The inherited shutdown handler saves the final batch.
Telemetry stays enabled; physics, AI decisions and rendering quality are unchanged.
`validate_ai_logging.gd` now covers both controllers, Texas flush phases, live
22-column ICR2 rows and final-batch preservation.

`profile_texas_start.gd -- --drive-player --seconds=60` attaches the bicycle
route-following driver to the actual player, keeping player physics, dirty air,
cockpit, virtual mirror and telemetry active. It starts on the race grid and
drives through formation and green. This adds test-driver overhead and is not
a human driving replay. The report includes player progress, telemetry status,
worst frame and counts above 33.333/50 ms. `--synchronized-logs` aligns the AI
flush timers again for comparison, retaining the buffered writer. Driving and
synchronized-log reports have separate filename suffixes. As with the TV test,
frame statistics exclude the first second after green.

Standalone rendered comparison, seed 42, 18 AI, 60 seconds after green, normal
60 Hz physics, player and all AI telemetry enabled:

| Flush timing | Mean frame | p95 | p99 | Worst | Frames >33.333 ms |
| --- | --- | --- | --- | --- | --- |
| Staggered | 17.713 ms | 29.632 ms | 33.582 ms | 45.719 ms | 39 |
| Synchronized | 17.464 ms | 26.706 ms | 33.085 ms | 46.051 ms | 30 |

Both completed two player laps with identical final speed (275.42 km/h), maximum
line error (5.753 m), and tow-tick count (29,213). Neither had a frame over 50 ms.
These results do **not** demonstrate a frame-rate improvement from staggering
flushes, and do not reproduce the reported 17 FPS counter reading. The change
removes the known synchronous I/O burst, but the user's cockpit stutter remains
unconfirmed in this standalone fixture. An initial restricted run failed to open
player telemetry and is excluded from the comparison. The logging regression
passed; Godot reported an ObjectDB leak warning at test shutdown.

## Packed race starts on Texas and Michigan (2 October)

Close traffic repeated the same opponent projections separately for every AI.
Session drivers now share the exact-position/index projection cache because they
use the same track transform, racing line and corridor. A moving vehicle or index
change invalidates its result immediately, including between drivers in one tick.
Reconfiguring a corridor detaches its cache from the old group. This does not
reduce the physics or AI update frequency.

Traffic and curvature previews also calculate the current side-clearance bounds
once per query, then apply those bounds at each preview distance. The independent
`validate_side_room.gd` oracle compared 54,000 samples on Mile Oval, Texas and
Michigan, including launch blends, lap wrapping, overlap release and squeezing
from both sides: maximum positional difference was zero. Projection equivalence,
AI planner, racecraft rules, queue and Michigan pit-merge checks also passed.

`profile_texas_start.gd` now supports `--track=michigan`, `--seconds=75`, `--tv`
and `--unshared`. The latter restores separate observer caches for comparison.
Run with normal rendering for frame percentiles; `--headless --fixed-fps 60`
measures simulation throughput and must not be reported as displayed FPS.
`--instrument` adds nested driver/projection/movement/step/grounding costs; these
overlap and must not be summed. Results are saved to `builds/<track>_start_after.json`
or `builds/<track>_start_unshared.json`. The unattended player is parked, and the
TV view follows an AI car. Timing excludes the first second after green.

Rendered standalone results on the local RTX 4060 Ti, seed 42, 18 AI from the
2001 field, normal 60 Hz physics, with player/AI telemetry enabled:

| Track / time after green | Mean FPS | Median frame | p95 frame | p99 frame | Median physics |
| --- | --- | --- | --- | --- | --- |
| Texas / 60 seconds | 59.9 | 16.656 ms | 17.628 ms | 18.234 ms | 11.556 ms |
| Michigan / 75 seconds | 59.6 | 16.649 ms | 17.715 ms | 23.481 ms | 10.968 ms |

These are moving TV-camera runs through the early laps, not measurements of the
editor's embedded play window or a driven cockpit. Occasional longer frames remain.
An additional Texas run with the cockpit stationary in the pits averaged 57.8 FPS.
The instrumented headless investigation showed per-field projection time falling
from 2.69 to 0.83 ms when sharing the cache; overall timings varied between runs,
so that microbenchmark is not a controlled estimate of the total FPS improvement.

## Driving cockpit workload (12 September)

The user still observed about 30 FPS while driving through the editor's Play
button. Earlier long tests used an exterior AI-follow camera. A new moving-player
fixture keeps the cockpit and both mirrors active while circulating with 15 AI.
It reproduces longer frames: before this change, the 30-second cockpit sample
averaged 23.77 ms (42 FPS), with 35.00 ms p95 and 50.11 ms p99 frames.

Two optimizations address CPU/render submission headroom:

- Runtime static scenery batching combines compatible opaque surfaces by material,
  render layers, shadow/GI mode, vertex format and 80-metre region. It combines
  755 source meshes into 113 batches, preserving all 53,890 triangles. Original
  collision nodes remain active. Custom shaders, transparency, billboards,
  triplanar materials, skins and blend shapes keep their original instances.
  `batch_static_visuals` on the practice scene permits comparison with the original
  visuals. This is a runtime operation; source art and editor geometry are intact.
- The AI speed planner reuses overlapping curvature samples and traverses the
  ordered lookahead once. Previously it repeatedly searched both the ideal and
  alternate paths for the same points. The new results match independent original
  lookups through lane blends and lap wrapping. Normal physics/decision frequency,
  speed limits, cornering parameters and mirror refresh rate are preserved.

In the same 30-second moving-cockpit fixture, planner cost across the 15 opponents
fell from 3.40 to 1.21 ms per tick. Mean frame time fell to 16.91 ms (59.1 FPS),
median 16.69 ms, p95 17.81 ms and p99 28.47 ms, including camera activation. These
are measured standalone fixture results, not a guarantee of identical timing in
the editor's embedded window or under other system loads.

`tools/profile_ai_costs.gd -- --drive-player` instruments real driver, planner,
vehicle movement and model calls without a separate planner warm-up. It attaches
a test driver to the player vehicle to produce repeatable cockpit motion. Add
`--soak` for a three-minute cockpit run with a two-second frame-timing warm-up and
per-minute percentile reports. Run performance measurements without other tests.

`tools/validate_visual_batches.gd` checks triangle preservation and instance
reduction. With `-- --capture`, it renders identical before/after views. Main-stand
draw calls fell from 400 to 80, and backstraight calls from 1,242 to 525. Mean
absolute image differences were 0.00043 and 0.00227 on the 0-255 channel scale;
both resulting views were visually inspected. The planner validator now also
compares 5,100 ordered samples against independent lookups.

The subsequent three-minute moving-cockpit run (two-second timing warm-up) averaged
16.781 ms per frame, or 59.6 FPS. Median was 16.643 ms, p95 17.715 ms and p99
26.291 ms. Mean engine physics time was 11.41 ms and opponent planning 1.17 ms.
There are occasional longer frames, so this is not a claim that every frame meets
16.67 ms or that the user's editor-hosted session has been measured directly.

The five-minute seed-1234 racing regression preserved the previous results exactly:
94 attempts, 14 passes, no car-to-car contact or road-clearance failures. Planner,
racecraft-rule and traffic regressions also pass. Geometry/collision meshes and
vehicle integration were not changed by these optimizations.

## Racecraft projection regression (11 September)

The first racecraft implementation projected every nearby player, parked car and
pit-exit car against all 805 racing-line segments on every racing driver's tick.
Only cars already racing used the seven-segment index hint. Mixed pit/race fields
were therefore much more expensive than the fully deployed, evenly spaced field
used by the earlier profiler. Once a physics tick exceeds the frame budget,
catch-up ticks can make rendering fall far below the reciprocal of a single tick.

`racecraft.gd` now builds planar bounds for groups of 16 segments when loading the
corridor. A full projection seeds an exact distance bound from the nearest group,
then checks only groups that could improve it. Segment order and exact projection
math are preserved, including vertex/seam ties. The existing racing-index search
is retained. One result per observed vehicle is cached by exact local position and
index hint, so stationary cars and repeated queries do not trigger another scan.
Caches reset with track configuration and have a bounded size.

This changes query cost, not update frequency, passing decisions, physics, rendering
quality, or the number of cars. `tools/validate_racecraft_projection.gd` compares
the optimized implementation against the original exhaustive function for 1,000
random positions, all line vertices, pit boxes, racing/non-racing mode changes,
cache hits, teleporting the player, and reconfiguration.

`tools/profile_racecraft.gd` isolates traffic and planning at 4/8/12/15 racing cars
with the remaining cars in their boxes. `-- --before` uses the original projection
as a test-only override; `--moving` moves racing cars between measurements.
The original stationary 12-car case spent 31.82 ms per tick in traffic alone;
the cached version measured 0.56 ms. This microbenchmark deliberately includes
cache hits and is not a live frame-rate measurement.

`tools/profile_racing_session.gd` makes the before/after rendered comparison with
moving cars. Each case runs for 12 wall-clock seconds, excluding its first two
seconds. Both implementations use the same seed, starting positions, vehicle
physics, camera, and normal 60 Hz physics clock. Run this benchmark alone:

| Racing / parked AI | Original median frame | Optimized median frame | Original / optimized physics |
| --- | --- | --- | --- |
| 8 / 7 | 234.99 ms (4.3 FPS) | 16.70 ms (59.9 FPS) | 28.80 / 7.89 ms |
| 15 / 0 | 16.65 ms (60.1 FPS) | 16.66 ms (60.0 FPS) | 12.98 / 10.80 ms |

The full-field case had no frame-rate collapse in this short fixture, but gained
physics headroom. The mixed-field case reproduces the severe collapse. The earlier
external/grass/no-shadows rendered fixture also measured about 60 FPS after the fix.
Results are from this machine's RTX 4060 Ti and remain workload dependent.

`tools/validate_full_field.gd -- --realtime` combines the five-minute, seed-1234
departure/racing regression with real-time rendered frame measurements. It writes
per-minute median/p95 frame times and mean engine physics time to
`builds/racecraft_live_soak.json`. Run with a renderer, without other benchmarks.

The completed real-time run held 16.65-16.68 ms median frames in every minute
(approximately 60 FPS), with 17.61-17.87 ms p95 frames. Mean physics time rose from
6.78 ms during early departures to 12.84 ms with the full field. All 15 cars joined
by 114.8 seconds. The original behaviour results were preserved: 94 attempts,
14 completed passes, no AI-to-AI contact or road-clearance failures, and no
unobstructed merge stops. This was an exterior follow-camera run on seed 1234.

The moving-query microbenchmark also measured substantial savings without reusing
stationary racing-car positions: traffic fell from 25.81 to 0.46 ms at eight racing
cars, and from 7.58 to 1.22 ms at fifteen. Parked-car results are still reused.
The exhaustive-equivalence, racecraft-rule and existing traffic validators pass.

## Earlier pit-query investigation

The 15-car field exposed repeated exhaustive pit-corridor searches. The path has
501 vertices; AI checked it several times each physics tick. Track session loading
now groups 20 segments in padded bounds and only runs exact distance checks in
matching groups. Speed-zone queries first reject positions outside their polygon.
Neither the final corridor test nor physics integration has changed.

`tools/validate_pit_queries.gd` compares the cached and exhaustive queries at 6,008
boundary/random positions and checks cache replacement on reload.

`tools/profile_rendering.gd` compares frozen views, then starts all 15 cars around
the racing line at 65 m/s and measures live views. Run normally and with
`-- --uncached-pits` to compare the broad-phase change. Results go to
`builds/render_profile.json` and `builds/render_profile_uncached.json`. Frozen frame
timings measure frame intervals, not isolated GPU time. Live runs use VSync and a
three-second minimum warm-up. Cases run sequentially, so car positions differ.

On the local RTX 4060 Ti, the live runs stayed near 60 FPS. With bounds disabled,
the physics monitor reported 14.2–15.6 ms across views; with bounds enabled it
reported 12.5–13.5 ms. These short runs did not reproduce the reported sustained
10–35 FPS collapse. Shadows produced thousands of extra draw calls, but disabling
them did not materially improve the live median in this test.

`tools/profile_simulation.gd` manually steps the field at 1/60 second in headless
mode and separately measures planning, zone queries and model integration. Its
extra planning pass warms the cache before driver execution, so the printed
driver time must not be interpreted as the cost of an untouched live tick.
