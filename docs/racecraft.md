# Two-wide AI racing prototype

For the current bounce response, stopping-distance guard, side-by-side room and
reduced straight-line speed spread, see [car contacts and pace](car_contacts.md).

Mile Oval practice now supports deliberate inside/outside passing, leaving room
through corners, holding a lane alongside another car, and returning to the fast
line once clear. It is enabled by the track's `ai/racing_corridor.json`. Missing
corridor data preserves the previous single-line driver. Stale or invalid corridor
geometry is rejected, with a warning when supplied to the driver.

## Tuning

`content/racecraft.json` is the game-wide source for tactical thresholds: pass
status distance, blend distance, commitment/abandonment limits, overlap handling,
road-edge reserve, collision guard, and the passing-speed factor. All values use
metres or seconds.

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

An approaching faster car can select an inside or outside attempt 20-110 metres
behind a leader. Relative speed or the existing cornering capability difference
provides the motivation. Lane checks inspect present and two-second projected
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
