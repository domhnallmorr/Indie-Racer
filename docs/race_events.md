# Race strategies and retirements

Each AI gets a repeatable race plan from its driver variation seed. Independent
draws choose standard fuel range (70%), two extra nominal laps per tank (20%), or
three extra laps (10%). The extra range comes from lower consumption at the same
tank capacity; pit entry still reserves enough fuel to reach the assigned box.
These are simple fuel-efficiency profiles with no pace penalty yet. Player fuel
use, practice and qualifying are unchanged.

Each AI independently has a 20% chance of a scheduled failure, distributed
between 5% and 95% of race distance. The event triggers when the car reaches that
progress while racing (a pending failure waits until it leaves the pits). This
does not guarantee exactly 20% of the field retires. A lapped car may not reach
its scheduled failure before the leader ends the race.

A separate seeded draw splits those failures evenly between **Engine failure**
and **Other**. The overall retirement probability, scheduled lap and fuel strategy
are unchanged. On average, only half of scheduled failures now cause a caution;
the exact mix still varies with the race seed.

Engine failure freezes classification as OUT (engine), shuts down the engine, emits
grey smoke from the rear, and disables all collisions and traffic blocking.
The car follows the track while moving left over three seconds and decelerating
at 6 m/s². It stops three metres inside the inner racing corridor, waits there
for 15 simulation seconds, then returns to its assigned pit box. It remains
retired and non-collidable. New smoke stops at recovery; existing puffs fade out.
Recovery continues if the race finishes during the sequence.

**Other** leaves the engine running and smoothly slows the car to 100 km/h along
the inside line (1.5 m inside the authored inner track boundary). It follows the
pit-entry route, observes the pit speed limit, and parks in its assigned box.
If the failure occurs too close to pit entry for a controlled slowdown, it takes
another inside lap. There is no smoke and no yellow. Timing continues during
the return; arrival shuts down the engine and permanently classifies the car
as OUT with reason `Other`, without refuelling or rejoining. The return uses
scripted movement and collision ghosting, as the existing retirement recovery
does, so the slow car cannot obstruct the race. It continues home even after the
chequered flag and is excluded from any unrelated caution queue.

Retirements apply to AI only. Engine failures trigger a [full-course caution](cautions.md).
Scheduled failures wait through formation and caution driving until the car is
racing again. Tyre wear is not yet implemented.

Checks: `tools/validate_race_events.gd` covers seeded distributions, real fuel
range, failure triggering, collision state, pull-over, stopped dwell, recovery
after race finish and frozen timing. `tools/validate_race_pitstops.gd` exercises
varied fuel consumption through actual stops with failures disabled for isolation.
`tools/validate_other_retirements.gd` checks normal, slow, pre-entry and post-entry
returns, both AI implementations, pit limiting, continued green racing, unrelated
cautions, finishing during a return, and permanent retirement at the box.
`tools/capture_engine_failure.gd` captures the smoke effect to `builds/engine_failure.png`.
Add `-- --pull-over` to capture the stopped car on the shoulder. Run
`tools/validate_race_events.gd -- --live` for a 30-lap, 15-AI race with eight-gallon
tanks, traffic and seeded failures enabled.
