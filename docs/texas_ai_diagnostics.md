# Texas AI behaviour investigation — 26 September 2026

The unattended simulation reproduced abrupt slowing and rapidly changing steering
targets. These observations use the current working-tree game, including its
existing uncommitted changes. The initial investigation below preserved gameplay;
the subsequent implementation and validation are recorded at the end.

## Procedure

- Texas, IRL 2001 field, 18 AI cars, seed 42, rolling-start race.
- Real formation and normal 60 Hz vehicle physics; Godot headless, fixed FPS 60.
- Player parked in the pits. Mechanical retirements disabled in the diagnostic
  fixture to isolate ordinary green-flag driving. Normal fuel and tyre systems run.
- Baseline: 180 seconds after green, every AI sampled each physics tick.
- Reproduction: the same seed for 150 seconds, with static-impact signal capture.
  All 162,018 trace rows match the corresponding baseline rows exactly.
- Comparison: 90 seconds after green with AI rivals and car collisions removed.
  Ghost cars are also ineligible for slipstream. This comparison isolates normal
  line following; it does not independently isolate each traffic subsystem.
- The ordinary `validate_texas_racecraft.gd` check also ran successfully: its
  opening minute had 27 attempts, zero completed passes, zero car contact frames,
  and zero samples outside its 9 m lateral limit.

Raw data, JSON summaries and incident plots are in
`builds/texas_behavior/baseline42/` and `builds/texas_behavior/clean42/`.
The repeat and static-impact records are in `builds/texas_behavior/recheck42/`.
These generated outputs are ignored by Git; keep them with this checkout if needed.

## Comparable first 90 seconds

Metrics below exclude the first 10 seconds after green, when launch constraints
are intentionally active. A target jump means a change in the observer's
reconstructed steering lookahead position relative to the corridor, not an
instantaneous displacement of the vehicle.

| Measurement, all 18 cars | Traffic | Ghost comparison |
| --- | ---: | ---: |
| Largest actual speed loss over 1 second | 64.8 km/h | 8.52 km/h |
| Largest steering-target change in one tick | 3.62 m | 0.25 m |
| Steering-target changes of at least 0.5 m | 63 | 0 |

The 180-second traffic run produced 48 passing attempts, 25 aborts and 10 completed
passes. It recorded 131 steering-target jumps of at least 0.5 m. These are
diagnostic candidates, not 131 independently confirmed visible defects.

## 1. Edge-speed guard repeatedly reduces an already reduced speed

Jaques Lazier, approximately 36.8–38.43 seconds after green:

- Speed falls from 369.7 to 271.6 km/h while the pre-traffic request stays close
  to 378 km/h. Maximum loss over one second is 64.8 km/h (18 m/s² braking).
- His centre reaches 8.118 m from road centre: 0.118 m outside the AI's 8 m
  preferred corridor, while remaining inside the existing 9 m validation limit.
- `reason` is `road_edge`. The selected lane remains -1 throughout the event.
- Side-room protection has moved the target from about -7.3 m to the -8 m limit.

`racecraft.gd::traffic_speed` calculates the edge cap from the **current actual
speed** multiplied by an offset-dependent reduction. When the offset persists,
the next tick reduces the already lower speed again. Even a small sustained
overshoot can therefore cause prolonged maximum braking rather than a modest,
stable speed cap. This is directly visible in the recorded target and actual speeds.

First repair candidate: make the normal edge response a stable, bounded correction,
coordinated with a steering target that has sufficient tracking margin. Retain a
separate stronger response for a genuinely large excursion. Simply raising the
edge threshold would conceal the feedback problem.

Plot: `builds/texas_behavior/baseline42/incident_AI_JaquesLazier_37.50.png`.

## 2. Side-room protection disappears at a hard gap threshold

Robbie McGehee at 71.683 seconds after green:

- Greg Ray's recorded gap moves from 8.994 m to 9.037 m.
- `_leave_side_room` stops applying its lateral constraint at `abs(gap) >= 9`.
- The steering lookahead target moves from -1.215 m to -4.831 m in one tick.
- `target_lane` remains zero; this is not a decision to change passing lanes.
- Reported line error immediately rises to 3.35 m. The reference driver then
  reduces the speed request because its target has moved away from the car.

First repair candidate: retain safe side separation during overlap, then release
the lateral constraint progressively once the neighbour is clear. Validate both
cars' clearance during the release; a generic steering low-pass filter alone could
delay necessary collision avoidance.

Plot: `builds/texas_behavior/baseline42/incident_AI_McGehee_71.68.png`.

## 3. Blocked/unblocked lane checks produce a discontinuous preview

Eddie Cheever at 59.117–59.650 seconds after green:

- The in-progress return to RACE switches blocked/unblocked nine times in 0.533 s.
- The chosen lane remains zero during the sequence.
- Each change switches `ahead()` between the present lane blend and an advanced
  blend for the steering lookahead distance. The resulting target moves back and
  forth by roughly 1.5–2.4 m.

First repair candidate: keep the preview continuous when a move is paused, and
require sustained clearance before resuming. A newly unsafe situation must still
block immediately. Do not treat a transient pause as a new passing decision.

Plot: `builds/texas_behavior/baseline42/incident_AI_Cheever_59.30.png`.

## Additional incident and limits

At 144.883 seconds, Robbie Buhl's actual speed drops from approximately 372 to
34 km/h in one tick while his requested speed remains near 372 km/h. He then
travels outside the corridor, reaching 40.83 m from centre before returning.
The run has zero **car-contact** frames; that counter does not include static
collisions. The repeat confirms a static collision at exactly the speed collapse:
84.65 m/s closing speed at world position (-372.4285, 0.3450, 149.4498). A second
static collision follows at 145.700 s, at (-342.3423, 0.6410, 123.7763), with a
40.02 m/s closing speed. The event records contain the collision normals, impulse,
energy, physics frame and collider instance IDs.

This is a separate confirmed collision response, not a requested braking action.
The follow-up below identifies the first collider as the racing-surface mesh and
adds focused regressions for this impact and a related seam stall.

The long run has 266 car-ticks outside the 9 m limit, all from that one excursion.
Thus the successful one-minute validator must not be described as a successful
three-minute safety run.

These results come from telemetry and code inspection, not a visual gameplay
review. The observer samples after a completed physics step; its path preview is
reconstructed from the recorded driver state and newly moved car position. It does
not intercept the exact pre-movement curvature command. Events should be checked
in a rendered replay after fixes. This investigation uses one seed and does not
cover arbitrary player moves, cautions, mechanical failures or pit-stop traffic.

## Reproduce

From the project directory in PowerShell:

```powershell
& 'C:/Users/domhn/Documents/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --fixed-fps 60 --script tools/diagnose_texas_behavior.gd --log-file tmp/texas_behavior.log -- --seed=42 --seconds=180 --tag=baseline42
python tools/analyze_texas_behavior.py builds/texas_behavior/baseline42
```

Use another `--tag` to preserve previous captures. Add `--clean-air` for the ghost
comparison. The analysis script accepts `--car AI_Cheever --time 59.3 --window 1.2`
to plot a chosen incident. The diagnostic is an observer, not a pass/fail safety
test: its exit status confirms it reached green, while its summary reports contacts
and boundary excursions explicitly.

The restricted environment denied the game's automatic player telemetry file in
`user://`; the diagnostic's separate project-local CSVs were written successfully.
Godot also printed certificate-store and shutdown object-leak messages. These did
not prevent the simulations from completing, and were not changed here.

## Implemented fixes and final validation

The driving changes are in `game/ai/racecraft.gd`:

- Edge caps use speed at the start of an excursion, with a 0.15 m reset margin,
  instead of multiplying an already reduced speed every tick. Large departures
  beyond 9 m retain a separate strong recovery cap.
- Steering and braking-path samples use the same committed lane blend. Selecting,
  blocking or resuming a destination no longer changes the preview instantaneously.
- Unsafe moves still block immediately; resumption requires 0.35 s of clearance.
- Side-room constraints release smoothly between 9 and 18 m longitudinal gap.
  Their lateral onset is continuous below 1 m, with the full original constraint
  retained from 1 m onwards.

The recorded static collision was a false lateral normal at a road triangle edge,
not a wall positioned in the racing line. `RacingSurface_col` reported both a
shallow floor normal and a steep edge normal at effectively the same point. The
old wall-response code reflected the car from that edge normal.

Texas now marks its road skin as `drivable_surface`. Shared vehicle contact code
verifies a walkable face on that same collider at the contact height before
discarding such a wall impulse. Real barriers remain ordinary colliders. A related
stall came from turning an upright box slightly into banking: the full-height
step sweep rejected an initial road overlap even though a small step was clear.
The controller now tries smaller bounded steps and permits only verified initial
road overlap; forward clearance and a walkable landing remain required.

The focused recorded-pose tests reproduce the old 103.4 → 9.5 m/s impact and the
103.5 → 0 m/s stall. The fixed controller retains speed in both, and the seam-stall
fixture advances 1.725 m during the expected 1/60 s step.

Final 180-second traffic captures, excluding launch for steering metrics:

| Metric | Original seed 42 | Fixed seed 42 | Fixed seed 1234 |
| --- | ---: | ---: | ---: |
| Car contact frames | 0 | 0 | 0 |
| Static impacts | 2 in repeat | 0 | 0 |
| Samples outside 9 m road limit | 266 | 0 | 0 |
| Maximum road-centre offset | 40.83 m | 8.14 m | 8.14 m |
| Steering-target jumps ≥0.5 m | 131 | 28 | 46 |
| Largest steering-target jump | 4.77 m | 1.52 m | 2.17 m |
| Jumps coinciding with a blocked/unblocked toggle | 23 | 0 | 0 |
| Largest actual one-tick speed loss | 93.91 m/s | 0.30 m/s | 0.30 m/s |
| Largest actual one-second speed loss | 337.97 km/h | 36.87 km/h | 56.86 km/h |
| Passing attempts / completed / aborted | 48 / 10 / 25 | 40 / 14 / 15 | 38 / 13 / 14 |

The baseline's largest speed loss includes its false collision. Ordinary traffic
braking still occurs in the fixed captures. The remaining target jumps are mostly
side-room corrections; this is a substantial reduction, not a claim that every
traffic manoeuvre is completely smooth.

Final outputs: `builds/texas_behavior/smooth_v3/` and
`builds/texas_behavior/smooth_seed1234/`; numerical comparison in
`builds/texas_behavior/comparison.json`. A rendered follow-camera sequence was also
captured and inspected under `builds/texas_behavior/visual/pack_00.png` through
`pack_04.png`. It is a short visual check, not a full visual replay of either run.

Passed checks:

- `validate_ai_smoothness.gd`: stable edge cap, side-room threshold continuity,
  unchanged path when pausing, and sustained-clearance resumption.
- `validate_texas_surface_contacts.gd`: both recorded surface failures and
  rejection of a genuine inner wall as a drivable edge.
- `validate_ai_safety.gd`, `validate_racecraft_rules.gd`, `validate_ai_planner.gd`,
  `validate_pack_release.gd`, `validate_green_launch.gd`.
- `validate_close_following.gd -- --live`: completed pass, zero contacts.
- `validate_racecraft.gd -- --inside-only`: completed pass, 3.26 m minimum overlap
  clearance, zero contacts.
- `validate_wall_contacts.gd` and `validate_surface_reentry.gd` cover the shared
  vehicle contact/step changes, including player and AI barrier responses.

The planner test now explicitly selects the bicycle roster it tests and disables
the authored corridor for its synthetic straight. Its previous default selected
the ICR2 reference-speed driver, so its uncapped-speed assertion tested the wrong
controller.

For a future full-race regression, run the observer with a new tag, then:

```powershell
python tools/analyze_texas_behavior.py builds/texas_behavior/NEW_TAG --check
```

`--check` requires completion, zero car/static contacts and road-limit excursions,
and no per-tick speed drop exceeding the reference car's commanded braking limit.
The plain observer still exits based on reaching green; inspect/check its saved
capture rather than treating that exit status alone as a safety result.
