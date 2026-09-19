# Race strategies and engine failures

Each AI gets a repeatable race plan from its driver variation seed. Independent
draws choose standard fuel range (70%), two extra nominal laps per tank (20%), or
three extra laps (10%). The extra range comes from lower consumption at the same
tank capacity; pit entry still reserves enough fuel to reach the assigned box.
These are simple fuel-efficiency profiles with no pace penalty yet. Player fuel
use, practice and qualifying are unchanged.

Each AI independently has a 20% chance of a scheduled engine failure, distributed
between 5% and 95% of race distance. The event triggers when the car reaches that
progress while racing (a pending failure waits until it leaves the pits). This
does not guarantee exactly 20% of the field retires. A lapped car may not reach
its scheduled failure before the leader ends the race.

Failure freezes classification as OUT (engine), shuts down the engine, emits
grey smoke from the rear, and disables all collisions and traffic blocking.
The car follows the track while moving left over three seconds and decelerating
at 6 m/s². It stops three metres inside the inner racing corridor, waits there
for 15 simulation seconds, then returns to its assigned pit box. It remains
retired and non-collidable. New smoke stops at recovery; existing puffs fade out.
Recovery continues if the race finishes during the sequence.

This first pass applies retirements to AI only. There are no cautions or tyre wear.

Checks: `tools/validate_race_events.gd` covers seeded distributions, real fuel
range, failure triggering, collision state, pull-over, stopped dwell, recovery
after race finish and frozen timing. `tools/validate_race_pitstops.gd` exercises
varied fuel consumption through actual stops with failures disabled for isolation.
`tools/capture_engine_failure.gd` captures the smoke effect to `builds/engine_failure.png`.
Add `-- --pull-over` to capture the stopped car on the shoulder. Run
`tools/validate_race_events.gd -- --live` for a 30-lap, 15-AI race with eight-gallon
tanks, traffic and seeded failures enabled.
