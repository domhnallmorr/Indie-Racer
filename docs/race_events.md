# Race strategies and retirements

Each AI gets a repeatable race plan from its driver variation seed. Independent
draws choose standard fuel range (70%), two extra nominal laps per tank (20%), or
three extra laps (10%). The extra range comes from lower consumption at the same
tank capacity; pit entry still reserves enough fuel to reach the assigned box.
These are simple fuel-efficiency profiles with no pace penalty yet. Player fuel
use, practice and qualifying are unchanged.

Race setup offers **Off / AI only / Everyone** (default Everyone). These rules
apply only during races. Off also disables random debris cautions. Each eligible
car has one 20% chance of a scheduled event between 5% and 95% of race distance.
AI fuel plans retain their independent seed stream. The player uses the same
event rules with a separate seed and keeps its normal fuel consumption.

The event mix below shares that single budget; adding types does not add
independent failure chances. These are provisional gameplay weights.

| Event | Share of events | Per-car race chance | Behaviour |
| --- | ---: | ---: | --- |
| Engine | 20% | 4% | Stop, smoke, DNF, caution |
| Transmission | 10% | 2% | Stop, DNF, caution |
| Half-shaft | 10% | 2% | Stop, DNF, caution |
| Turbo | 20% | 4% | Limp to pits, DNF, no yellow |
| Electronics | 15% | 3% | Limp to pits, DNF, no yellow |
| Puncture | 15% | 3% | Limp to pits, full service, rejoin |
| Spin / crash | 10% | 2% | Turns only, always DNF and caution |

Spins wait for a turn, using horizontal reference-path curvature (over 0.025
radians across two 15-metre tangent samples). The scripted animation rotates the
car while slowing it toward the outside corridor edge. It is a simplified
incident, not a physical collision/damage simulation. Retired cars are recovered
to their assigned boxes after stopping and a 15-second dwell. AI mechanical
stops retain the existing crew/truck visual recovery; scripted spins and player
stops currently use direct recovery without that cosmetic crew sequence.

Punctures reduce player grip to 65% of its current tyre grip, with braking
assistance toward 100 km/h. The player keeps steering and drives to its box.
AI uses the existing controlled pit-return route. Both receive a full fuel and
tyre service, then may rejoin; timing continues and no retirement is recorded.
A puncture allows emergency service under closed pits. Terminal failures cannot
be repaired or restarted, even by requesting pit departure manually. Player
messages distinguish punctures, return-to-retire failures, and confirmed DNFs.

Debris has a separate **8% chance per race**, at most once, scheduled between
10% and 90% of race distance. It triggers a caution without retiring a car.
Following a restart, spins and debris wait ten leader laps; their pending events
are retained. Mechanical failures are never cancelled by this spacing rule.
All scheduled car events wait during formation, yellow and pit-lane driving.
A lapped car may finish before reaching its scheduled event. Returning to the
same weekend retains the seed and schedule; a fresh weekend gets a new seed.

Engine failure freezes classification as OUT (engine), shuts down the engine, emits
grey smoke from the rear, and disables all collisions and traffic blocking.
The car follows the track while moving left over three seconds and decelerating
at 6 m/s². It stops three metres inside the inner racing corridor, waits there
for 15 simulation seconds, then returns to its assigned pit box. It remains
retired and non-collidable. New smoke stops at recovery; existing puffs fade out.
Recovery continues if the race finishes during the sequence.

For engine failures under yellow, a separate visual recovery keeps a copy of
the stopped car at the scene after the simulation recovers it. On the second
pace-car lap after the incident, a white/red safety pickup with flashing amber
lights parks behind it and two marshals attend. On lap three, a flatbed appears
ahead, loads the car over ten seconds, then carries it along the apron and
pit-entry route. The car becomes visible in its assigned box on arrival.
All recovery vehicles and crew are non-colliding visuals: they do not change
classification, caution length, pit permissions, or race traffic. If the pace
car returns early or the race finishes, the remaining visual schedule advances
at the equivalent pace speed and completes normally. Further incidents have
their own recovery scenes. `tools/validate_recovery_visuals.gd` checks the
sequence, loading, cleanup, and early-ending cautions; add `-- --capture` in a
rendered run for screenshots of the pickup and loaded flatbed.

**Turbo/electronics failures** leave the engine running and smoothly slows the car to 100 km/h along
the middle of the apron, 3 m below the inside track edge and entirely left of
the inside white line after its gradual pull-over. It follows the
pit-entry route, observes the pit speed limit, and parks in its assigned box.
If the failure occurs too close to pit entry for a controlled slowdown, it takes
another apron lap. There is no smoke and no yellow. Timing continues during
the return; arrival shuts down the engine and permanently classifies the car
as OUT with the specific failure reason, without refuelling or rejoining. The return uses
scripted movement and collision ghosting, as the existing retirement recovery
does, so the slow car cannot obstruct the race. It continues home even after the
chequered flag and is excluded from any unrelated caution queue.

Checks: `tools/validate_race_events.gd` covers seeded distributions, real fuel
range, failure triggering, collision state, pull-over, stopped dwell, recovery
after race finish and frozen timing. `tools/validate_race_pitstops.gd` exercises
varied fuel consumption through actual stops with failures disabled for isolation.
`tools/validate_expanded_incidents.gd` checks the shared distribution, AI/player
puncture service, terminal pit returns, turn-only spins, recovery and mode toggles.
Add `-- --live` for a real AI puncture return, service, pit exit and resumed lap
scoring. Repaired cars restore their original collision layers before departing.
`tools/validate_restart_failure_grace.gd` now checks deferred debris, the ten-lap
spacing boundary and overdue mechanical failures surviving a restart.
`tools/validate_other_retirements.gd` checks normal, slow, pre-entry and post-entry
returns, both AI implementations, pit limiting, continued green racing, unrelated
cautions, finishing during a return, and permanent retirement at the box.
`tools/capture_engine_failure.gd` captures the smoke effect to `builds/engine_failure.png`.
Add `-- --pull-over` to capture the stopped car on the shoulder. Run
`tools/validate_race_events.gd -- --live` for a 30-lap, 15-AI race with eight-gallon
tanks, traffic and seeded failures enabled.
