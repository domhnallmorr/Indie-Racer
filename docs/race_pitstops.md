# Race fuel stops

Race Weekend Setup includes a temporary **Max Fuel Capacity (US Gallons)** setting,
from 2 to 35 gallons (default 35). It applies to player and AI in races; practice
retains its normal tank and pit fuel selection. Standard consumption is 35/60 gallons
per nominal mile-oval lap; some AI gain two or three laps per tank through lower
consumption. See [race strategies and failures](race_events.md). Formation and pit
lane distance also consume fuel, and the existing fuel-weight pace effect remains.

For a quick test, select **10 laps and 3 gallons**. This gives about five nominal
laps per tank and produces repeated stops in the race.

AI checks fuel at the pit approach. With roughly one lap remaining (including a
safety allowance to reach its assigned stall rather than starting another lap), it
follows the pit entry route to its assigned stall, stops for a randomly sampled
10-13 seconds, refills
to the selected capacity, then rejoins using the existing pit exit/merge logic.
Pit-lane speed limiting and race lap counting remain active. Service time is fixed
when the stop begins, regardless of fuel added, then counts down on the LCD. No tyres, repairs or pit crew animation
are included in this first version; existing pit collision ghosting is retained.

The player also receives a randomly sampled 10-13 second refill when stopped and aligned in their
assigned race stall. The LCD shows the refill countdown; control is released
automatically when service finishes. A finished session does not release cars
from service.

Regression checks:

- `--headless --path . --script res://tools/validate_fuel.gd`
- `--headless --path . --script res://tools/validate_race_pitstops.gd -- --traffic`
- Add `--full-field` to test the complete ICR2 roster.

Known integration issue: the seeded 15-car traffic test completed the race and
all cars refuelled, but Taylor Reed fell below the track after the first rejoin.
The regression now reports below-track movement as a failure; full-field traffic
and track-contact behaviour still need investigation. Two-car traffic tests
complete repeated stops without this issue.
