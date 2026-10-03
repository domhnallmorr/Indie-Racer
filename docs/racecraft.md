# Two-wide AI racing prototype

For the current bounce response, stopping-distance guard, side-by-side room and
reduced straight-line speed spread, see [car contacts and pace](car_contacts.md).

Mile Oval practice now supports deliberate inside/outside passing, leaving room
through corners, holding a lane alongside another car, and returning to the fast
line once clear. It is enabled by the track's `ai/racing_corridor.json`. Missing
corridor data preserves the previous single-line driver. Stale or invalid corridor
geometry is rejected, with a warning when supplied to the driver.

Failed passing targets are released even when another car is nearby. Returning
to the racing line still requires a clear path, so abandoning a distant opponent
does not force a move across an occupied lane. This prevents the Michigan
Buhl/Boat/Calkins queue from preserving targets hundreds of metres ahead.

An attempt also ends early when the target stays more than 20 metres ahead and
at least 8 metres farther away than the best gap during that attempt for three
continuous seconds. This timer starts only after two seconds of commitment and
with the lane transition complete; recovering below either gap threshold resets
it. Close battles keep their commitment. Abandonment retains the four-second
retry cooldown and the existing swept-path clearance checks before returning to
RACE, including protection for rear traffic and cars alongside. These thresholds
are `passing_losing_min_gap_m`, `passing_losing_gap_growth_m`, and
`passing_losing_duration_s` in the shared tuning file. The existing 50-second
no-progress timeout remains as a fallback.

A committed attempt also reconsiders its lane after two seconds behind a
same-lane car when its requested pace exceeds that car's speed by the configured
closing threshold. From a passing groove it tries the racing line first, then
the opposite groove. Every choice must have pull-out clearance and a clear swept
path, including rear traffic in any lane it crosses. Current lane transitions
and genuinely side-by-side attempts keep their existing commitment.
`tools/validate_racecraft_queue.gd` covers these decisions and safety restrictions.

Completed passes no longer require a fixed 22 m lead. Rear clearance uses the
actual collision-box rear/nose extents (4.35 m combined for two open-wheel cars),
a 2 m bumper margin, and the distance the rear car could close during the remaining
lane blend plus a 0.6 s settling allowance. Texas uses a 70 m blend: at 105 m/s a
passing-groove-to-RACE move has 0.67 s of commanded blend, with physical following
allowed to settle afterwards. The two-second minimum pass commitment remains.
Equal-speed rear traffic therefore needs approximately 6.35 m between car origins,
not 22�24 m. Faster rear traffic requires more clearance. The margin and settling
allowance are tunable as `rear_merge_bumper_margin_m` and `rear_merge_settle_s`.
The same prediction governs rear lane-clear checks; side-room steering releases
continuously as bumper clearance rises from zero to the margin. Other overlapping
cars still block the return independently. Front-traffic planning is unchanged.

## Tuning

`content/racecraft.json` is the game-wide source for tactical thresholds: pass
status distance, blend distance, commitment/abandonment limits, overlap handling,
road-edge reserve, collision guard, and the passing-speed factor. All values use
metres or seconds.

The passing-speed factor is neutral (`1.0`), including the built-in fallback.
Committing to an overtake does not increase the AI's target pace in corners or
on straights. Passes rely on the existing driver pace difference and lane
selection; abandoning an attempt no longer removes an artificial speed bonus.
This factor remains available for explicit track tuning, but is not drafting.

`green_launch_guard_delay_s` suspends only the close-range collision guard for the
opening launch from formation. `green_launch_lane_hold_s` keeps each car in its
formation row for a minimum duration. Formation and launch use fixed lateral
positions relative to the track corridor, rather than offsets/blends of the
racing line (which moves across the track). After the timer, a car waits while
another car is alongside within `nearby_room_gap_m`, then blends to RACE only
when the lane-clear check permits it. Traffic protection resumes independently
when the guard delay expires. Mile Oval's row centres are 6 metres apart.

`green_launch_acceleration_mps2` and `green_launch_acceleration_window_s` cap
the initial kinematic acceleration without affecting race pace. The default is
5 m/s² for five seconds. `green_launch_row_delay_s` delays each two-car grid row
by 0.1 seconds, so the front row launches first and later rows spread subtly
down the straight.
The driver keeps built-in values only as a safe fallback if that file is invalid.

A track can override only the values it needs by adding
`content/tracks/<track_id>/ai/racecraft.json`:

```json
{
  "schema_version": 1,
  "overrides": {
    "lane_blend_distance_m": 45.0,
    "passing_commit_max_gap_m": 80.0
  }
}
```

Overrides are validated independently, so an invalid field retains the game-wide
value rather than disabling the AI corridor.

## Track paths

`tools/build_racing_corridor.py` reads the current racing line and the track
generator's geometry definitions without running Blender or changing either file.
It produces car-centre boundaries at -8/+8 metres from road centre, leaving reserve
inside the physical -10/+10 metre racing surface. The inside groove uses
`-4 + 0.35 * fast_line_offset`; the outside uses `3.5 + 0.35 * fast_line_offset`.
Both follow the actual banking and remain 7.5 metres apart laterally. The generous
separation accommodates the current steering controller's tracking error.

All paths share racing-line sample indices and wrap across the lap seam. The file
includes the reference points so editing the race line cannot silently leave the
passing paths misaligned. Run `python tools/build_racing_corridor.py` after changing
the racing line. This generator is specific to Mile Oval; other tracks need their
own authored, validated corridors.

## Decisions and control

`game/ai/racecraft.gd` owns decisions and path selection; `oval_driver.gd` still
drives the shared vehicle physics with steering, throttle and brake inputs.
Nearby rivals, including the player, are projected into distance around the lap
and lateral distance from road centre. Racing cars use their path-index hint;
vehicles without a racing index use an exact spatially indexed projection. Results
for unchanged positions are cached; see [performance](performance.md). Cars outside the racing
surface band are excluded, while pit-exit driving retains its existing controls.

An approaching faster car normally selects an inside or outside attempt 25–40
metres behind a leader. A car already following inside that window may also pull
out when its unguarded requested pace exceeds the leader's speed. The closest
leader is considered first, so a further car cannot hide a nearer obstruction.
Lane checks inspect present and two-second projected
longitudinal gaps and the lateral space the manoeuvre crosses. A leading AI holds
its established groove while an attacker uses a clearly separated passing groove.
This avoids an early defensive pull to the inside and requires the attacker to
complete the move. Established overlap takes priority over the clean-air line. A
blocked lane change holds the existing target instead of crossing another car.
The `leaving room` status is reserved for a committed attacker less than ten metres
behind that is predicted to reach bumper overlap within roughly one second; distant
closing traffic leaves the driver in the normal `clear` state.

A centre-line follower behind a car does not block that car from moving away into a
clear passing groove. A rear car blocks the move only when it already occupies, or
has committed to, that same destination groove. This prevents single-file queues
from becoming a lane-change deadlock.

A close same-line leader does not block moving away into a clear passing groove.
The projected longitudinal gap must remain above the bumper-overlap threshold
plus 2 m throughout the remaining lane blend. A car crossing the swept path,
occupying the destination or already committed to it still blocks the move.
The longitudinal collision guard remains active until lateral clearance exists.
This allows a faster car to escape the 9 m following equilibrium without cutting
through its leader or a neighbouring car. No artificial passing speed is added.

Texas's passing grooves are 7.6 m apart within the existing 16 m car-centre
corridor. The former 5.2 m spacing could leave both grooves less than the 3.2 m
clearance requirement from RACE, preventing a follower from making a usable move.
The clean-air racing line, track width and speed profiles are unchanged.
`tools/validate_close_following.gd -- --live` exercises a close three-car queue,
safe pull-out, occupied/crossing lanes, fast closure and a completed live pass.
Run `tools/validate_texas_racecraft.gd` with `--headless --fixed-fps 60` for the
18-car formation and opening minute, checking passes, contacts and road bounds.

A pass completes after the opponent falls 22 metres behind, with a two-second
minimum commitment. An attempt without overlap aborts if the opponent gets 110
metres ahead after that commitment, or if the gap has not improved for 50 seconds
while the opponent remains more than 20 metres ahead. It waits four seconds before
another attempt. These are prototype heuristics, not a strategic assessment of
predicted lap-time gain.
An already selected move remains `closing` until the opponent is within ten metres;
only then does the HUD report `passing inside` or `passing outside`.

Lane blends progress over approximately 30 metres per unit of blend (60 metres
for a complete inside-to-outside transition). Steering lookahead and the curvature/
banking braking envelope sample the same blended path. Cars only stop following a
leader when both actual and intended lateral clearance are sufficient. A modest
eight-percent tow benefit on a committed passing groove helps closely matched cars
complete a move instead of remaining side by side indefinitely. Tracking
error beyond seven metres from road centre also reduces speed to preserve the
edge reserve without changing an established lane priority. Vehicle grip, engine
power and position are never overridden by racecraft.

Road normals use a bounded spatial cache because the planned paths now move.
Clean-air driving retains the calibrated ideal line and vehicle-dependent speed
planner. Pit departure, speed limiting and merge commitment remain separate.

## Observing and validating

Restart practice, then use **6/7** to follow opponents. The followed driver's HUD
shows `closing`, `passing inside`, `passing outside`, `alongside`, `leaving room`, `holding lane`
or `returning` as appropriate. Existing F12 AI telemetry also records the state,
current/target lane blend, opponent and completed-pass count. Traffic reasons keep
following and `road_edge` speed constraints separate from tactical state.

- `tools/validate_racecraft_rules.gd`: automatic selection, lap-seam gaps, occupied
  lanes, rear closing traffic, return clearance, edge response, timeout/cooldown,
  path bounds and stale-path rejection.
- `tools/validate_launch_geometry.gd`: formation-to-green target continuity for
  both rows around the track, plus release when the lane becomes clear.
- `tools/validate_green_launch.gd`: full formation and 12 seconds after green,
  checking car contacts, overlap separation and row-release staggering.
  Run headless with `--fixed-fps 120`; the undriven player is parked in the pits.
  Seed 42 after the lane-hold fix: zero AI contact frames over 30 racing seconds,
  minimum overlap separation 4.02 m, and three cars released to normal racecraft.
- `tools/validate_racecraft.gd`: 120 simulated seconds each for inside, outside and
  automatically selected passes, using the normal 1/60-second vehicle step. Checks
  actual pass completion, corner overlap, car-to-car contacts and road clearance.
  Run with a renderer and `-- --capture` to save `builds/racecraft_corner.png` at
  the first side-by-side corner; capture mode is a visual fixture, not a test run.
- `tools/validate_full_field.gd`: five-minute seed-1234 field, with completed-pass,
  vehicle-contact and road-clearance checks in addition to departures and laps.
- Existing AI, planner, traffic and logging validators cover the shared behaviour.

The two-car scenarios with a 0.82 cornering-utilisation leader completed all three
passes without contact, including corner overlap. Minimum lateral separation was
7.38-7.52 metres during overlap; maximum road-centre offset was 6.63 metres. The
reference roster retained 23.833/23.835-second best laps. A rendered corner capture
was inspected to confirm that both cars occupy distinct grooves on the road.

The final five-minute seed-1234 field produced 94 attempts and 14 completed passes,
zero AI-to-AI contact ticks and zero ticks beyond the nine-metre road-centre
clearance threshold. Maximum actual offset was 8.610 metres. All 15 cars joined by
114.8 seconds and completed 6-9 timed laps; no unobstructed merge stops occurred.
The first field run exposed a brief edge excursion; the seven-metre tracking-error
speed response was added and the full field rerun with the original threshold.

The headless simulation profiler measured about 12.45 ms for all 15 driver updates
in its warmed, five-second fixture on this machine. This is not a rendered FPS
guarantee or a worst-case pack-racing benchmark.

## Limits

This is a two-wide prototype: no deliberate blocking, drafting, three-wide strategy,
panic paths, crash recovery, race starts, flags or pit-return strategy. Drivers use
simple gap prediction and can abandon viable attempts or remain in queues. The
player is included in proximity checks, but unpredictable moves and collisions
are not guaranteed recoverable. Wider fields, different seeds, car dimensions and
new tracks need further validation. Race-line error can legitimately exceed the
old five-metre threshold during a pass; road-centre clearance is the field safety
metric now, while the isolated reference run still checks the ideal line.

## Race pack release (September 2026)

The green-start lane hold now ends after its configured timer, even with a car
alongside. Steering blends out of the physical formation lane while the normal
lane planner and side-room correction remain active. Collision avoidance checks
the actual protected steering path rather than only the desired passing lane;
3.1 m lateral separation at both the current position and planned path permits
independent pace. Same-lane braking and occupied-lane checks remain active.

If a trailing car stays beside the same neighbour for six seconds with less than
0.5 m/s relative speed, it can ease off by 1.5 m/s for up to four seconds. A
16-second cooldown prevents repeated yielding; car names break a dead-even tie.
This only creates longitudinal room: it does not authorize a lane change through
another car. The normal pass planner can try again once a safe opportunity exists.

The seed-1234, 15-car diagnostic over 150 seconds after green recorded zero
AI-to-AI contact frames and all cars released their launch constraint. Casey
Grant's latest lap improved from 24.256 s in the previous traffic run to 21.993 s,
matching its prior clear-track pace. This is one automated race configuration,
not a guarantee for every grid or player interaction. The roster was unchanged.

Checks: `validate_pack_release.gd` covers transient and sustained overlap,
one-sided yielding, cooldown, launch release and same-lane protection;
`validate_ai_safety.gd`, `validate_racecraft_rules.gd` and `validate_green_launch.gd`
cover braking, lane occupancy and the start. The live inside-pass scenario also
completed without contact, with minimum overlap separation of 3.28 m.
`diagnose_race_pace.gd` now records contact frames, yield ticks and launch weight
alongside its lap times and traffic-guard statistics.
