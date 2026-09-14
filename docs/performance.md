# Performance investigation

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
