# AI vehicle physics

For the current passing paths, two-wide decisions and traffic validation, see
[AI racecraft](racecraft.md). The dated calibration notes below describe earlier
single-line behaviour.

## Pit-exit blending (10 September)

Pit exit uses the same curvature/braking planner as racing, including lookahead
beyond the exit into the next racing-line bend. Cached cumulative route distances
keep those queries inexpensive. A 120 m Hermite blend connects the end of the pit
path to the actual racing line with matching endpoint directions.

The yield gate is 30 m before the lateral blend, on the apron. Conflicting traffic
reduces the speed target using remaining stopping distance. Once a clear gap is
accepted near that gate, the driver commits: rear traffic cannot re-trigger a stop
halfway across the racing surface. Ordinary following control remains active.
The Mile Oval merge check finds where the remaining exit route first overlaps
each racing car's lateral corridor, then projects longitudinal separation through
the rest of the blend. Safe same-speed or already-passed traffic no longer causes
braking just because it is within 85 m. This uses a constant-speed prediction
(20 m/s minimum for the merging car's initial acceleration); the backstraight
conflict corridor is still specific to this track.

Telemetry distinguishes `merge_yield_<car>` from `collision_guard_<car>`. The full-field
test now counts end-of-exit stops before commitment too; the previous check only
counted unobstructed stops after commitment and missed apron hesitation. Run it
with `-- --merge-only` to check all 15 departures without the repeated-lap phase.

The two-car 180-second regression retained 23.836/23.837-second best laps. Traffic
tests cover apron yielding, late rear traffic after commitment, fast closing cars,
and the route's tangent join. The full-field validator records join speeds and
checks for unobstructed stops during the lateral merge.

## Shared handling

The two AI cars use the same bicycle model, road-contact controller and vehicle physics CFG files as the player, including the current stability assists. `human_controlled=false` disables keyboard/wheel handling and the wheel setup UI. The route driver supplies throttle, brake and steering; it never assigns vehicle speed.

The driver retains the pit-box departure route, 80 km/h geographic limiter, merge checks and a close-range traffic collision guard. Waiting cars hold the brake. Automatic gearing uses the shared engine and gearbox configuration.

Racing and pit exit have no fixed straight or corner speed caps. Clear straights request full throttle; engine power, gearing and drag determine attainable speed. The geographic pit limiter still takes priority, and the initial manoeuvre out of the stall retains its 55 km/h ceiling. Upcoming corner speeds come from path curvature, tyre grip, mass, downforce and cached road normals for banking. A proportional cornering utilisation of 0.92 reserves capacity for corrections and combined loads. Braking utilisation is 0.80 with a 5-metre margin. Lookahead grows from 200 metres with stopping distance and a two-second speed margin, bounded by one circuit. Steering accounts for the shared speed-sensitive steering range and includes a small allowance for understeer. Actual speed follows from simulated forces; throttle is released whenever braking is requested.

These remain prototype drivers: no overtaking planner, deliberate mistakes, tyre temperatures or suspension simulation. The grip-based speed estimate is approximate; combined loads use a reserve rather than a full friction-circle prediction. Road-normal sampling assumes static road collision on layer 1 and falls back to flat road if unavailable. Compare clean timed laps against the player before tuning utilisation. `tools/validate_ai.gd` checks shared parameters, departures, limiter release, merging, repeated laps and line error. `tools/validate_ai_planner.gd` checks vehicle-dependent corner speed, banking, uncapped straights and extended lookahead.

## Mile Oval pace calibration

The line generator (`tools/build_race_line.py`) uses an outside-straight (+6 m), low-apex (-6 m before smoothing) groove with lateral transitions extending 100 metres onto the straights and 45-metre smoothing. The previous 14-metre lateral weave created tight entry and exit bends separated by a flatter middle, prompting two large braking phases per end of the oval. The new line is projected onto the existing banked road; track geometry and player physics are unchanged.

The 8 September recording contained a 23.232-second player lap and 28.618-second clear AI laps. With the revised line and utilisation, a 180-second headless run at the normal 1/60-second physics step produced five timed laps per AI, bests of 24.159 and 24.160 seconds, and maximum line error below 3.4 metres. Blue's best lap had a 212.8 km/h minimum, 295.1 km/h maximum, and brake input above 2% for about 16% of the lap (previously 35%). These are reference results for this car/track, not universal difficulty targets.

The AI validator now checks a 24-second reference pace ceiling in addition to the existing line corridor and pit checks. Its accelerated clock preserves the normal physics step. Add `-- --capture` to save both diagnostic CSVs in the project root for analysis. Retune the reference assertion deliberately if vehicle physics or track geometry changes.

The centre-groove calibration above was subsequently revised after visual feedback: its straight placement was too central and the actual apex too high. With the outside/low-apex groove and cornering utilisation 0.92, both AI ran 24.24-second best laps over five timed circuits. Actual straight offsets were +6.0 m and apex offsets were -5.0 to -4.3 m relative to road centre, with maximum line error below 4 m. `python tools/validate_ai_line.py ai_validation_AI_Blue.csv ai_validation_AI_Yellow.csv` checks target and captured paths for outside straight placement, low apexes and road-edge clearance.

## Braking alignment (9 September)

Corner constraints now use curvature centred at their stated distance, including a sample behind the car and across the lap seam. Braking distance accounts for the car's offset from the nearest path vertex. The previous forward-only stencil applied curvature ten metres early, on top of its 15-metre margin. The margin is now 5 m. A centred 50-metre curvature stencil reduces sensitivity to short transition peaks without changing the driven line. This remains an approximate planner and should be revalidated on tighter layouts.

Clear racing uses a 0.5 m/s braking tolerance and a 0.5 baseline throttle command, avoiding throttle cuts for tiny speed errors and improving speed holding. Pit limits and traffic constraints retain strict control. Vehicle physics, grip utilisation and the racing line are unchanged by this calibration.

The latest player reference is 22.412 s, versus the prior 24.242 s AI. Validation produced bests of 23.837/23.836 s over five timed laps per car. At the geometric corner entries speed rose from approximately 222 to 242 km/h; braking onset moved from 104–112 m before entry to approximately 81–89 m (CSV sampling is coarse). Top speed reached 295 km/h. Actual apex offsets remained about -5.2 to -4.5 m, and full-run line error stayed below 4 m. The remaining gap to the player is approximately 1.42 s.
