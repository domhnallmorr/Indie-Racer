# Full-course cautions

Race engine failures call a full-course yellow. `Other` failures instead return
to their box along the inside line without a yellow; see [retirements](race_events.md).
**F8** calls a manual test
caution during a running race. Practice, qualifying and the initial formation
do not accept cautions. Contacts do not yet trigger them.

Race Control closes the pits immediately and records the physical queue behind
the leading active car. The pace car leaves its bay along the pit route, waits
to pick up that leader, and circulates at the track's pace speed (80 km/h on
Mile Oval). Cars catch the train at up to 130 km/h and form a single file with
25-metre target spacing. Player steering remains manual; throttle/brake
assistance limits speed to the assigned queue target. The HUD names the car to
follow and instructs a player who passes it to let it back through.

Pits open once the field has gathered and at least 15 seconds have elapsed.
Cars already in the pits or committed to entry when yellow appeared may finish
their stop. A new normal player stop waits for opening before service starts.
Emergency refuelling is permitted with one nominal green lap of fuel or less.
Pit returns join the tail. AI holds on the exit apron until the train has
passed; the player must follow the HUD and yield when rejoining.

During open pits, AI stops if it needs fuel to finish and has used at least 20%
of its tank, or if it reaches its usual low-fuel threshold. After at least one
pace-car lap with pits open, completed AI pit cycles and a gathered field,
Race Control announces one to green and switches off the amber lights. A further full pace-car lap precedes the
return to the pits. The leader crossing the existing Turn 4 green point with
the pace car clear and the queue formed releases everyone to racing. Another
incident cancels an announced restart. The same pace car supports repeated
cautions.

These are deliberately simplified game rules, not a particular season's
rulebook. Lapped cars retain their physical place in the train. There are no
wave-arounds, free laps, double-file restarts or closed-pit time penalties.
Timing continues under yellow, pit-lane laps still count, and restarts never
reset the clock or lap counts. A race can finish under yellow at its configured
lap distance. A player who stops on the circuit or ignores the assigned order
can hold up the restart; use R to recover to the pits if stranded.

The distance-based fuel model uses 45% of normal burn during yellow for both
player and AI. This is a tunable gameplay approximation, not measured engine
fuel flow. The Fuel panel continues to show range at green pace, to avoid
suggesting that a yellow-only range is sufficient to finish after the restart.

`game/race/race_control.gd` owns the rules separately from `Session.Status`.
The session stays RUNNING so timing, pit servicing and recovery continue.
The formation driver is reused for caution driving; ordinary racecraft resumes
at green. Pace-car deployment and circulation are in `game/race/pace_car.gd`.

Validation: run Godot headless with `--script res://tools/validate_caution_rules.gd`
for lapped-car ordering, pit permissions, emergency fuel, duplicate incidents
and restart invariants. `--script res://tools/validate_cautions.gd` exercises a
live full-field failure, field pickup, fuel stops, restart, repeat deployment
and a finish under yellow. Add `-- --small` for the two-car roster, or
`-- --mixed --fast-start` for a split-field pit strategy with a seeded moving grid.
