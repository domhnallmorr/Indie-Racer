# Two-car AI prototype

Practice includes **AI_Blue** and **AI_Yellow**, retaining the original basic car
controller while the player now uses bicycle physics. They share the collision
approach and pit-limiter zone. They have no cockpit viewports and their
external models remain visible to the player's mirrors.

The three box assignments are in `content/tracks/mile_oval/session.json`:

| Car | Box | Track-local position, metres | Earliest departure |
| --- | --- | --- | --- |
| Player | player_pit_01 | -81.04, 0.025, 92.75 | Player controlled |
| Blue | ai_pit_02 | -71.152, 0.025, 92.75 | 10 seconds |
| Yellow | ai_pit_03 | -61.264, 0.025, 92.75 | 4 seconds |

All face -90° about Y, down the pit lane. The forward car departs first, leaving
room for the following car to pull out. A basic traffic check can delay departure.
The HUD reports each AI's current phase and speed. **6** follows blue, **7** follows
yellow, **4** returns to the player's exterior, and **5** returns to cockpit.
Right-drag orbit and wheel zoom also work when following an AI car.

## Routes and controls

`game/ai/oval_driver.gd` has WAITING, PIT_EXIT and RACING phases. It generates a
smooth 36 m stall departure, joins the existing `ai/reference_paths.json` pit path,
then extends the final taper across the apron to join the racing line on the
backstraight. The player and AI share the 80 km/h zone; the limiter releases before
T1. AI then targets 120 km/h through the exit route, rather than accelerating to
its racing pace in the narrow bypass.

`content/tracks/mile_oval/ai/race_line.json` holds editable metric coordinates for
the closed race line and target speeds (210 km/h straights, 170 km/h corners).
This first line follows the reference road centre; it is not an optimised racing
groove. The driver anticipates upcoming curvature and supplies steering, throttle
and brake to `drive_step()`. Cars are never teleported around the route.
Regenerating the track does not overwrite this separate race line: update it when
the layout changes. The main practice scene currently loads this Mile Oval line.

AI applies a simple forward spacing rule and checks for nearby race traffic at
the backstraight merge. This is preliminary yielding, not full racecraft: no
overtaking, defending, robust accident recovery, pit return, or strategic behaviour.
An obstructed car can wait behind the obstruction. The same box collider and basic
physics limitations apply to player and AI. Neither AI driver receives WASD input.

The `ai_enabled` export on the main scene can disable opponents for isolated
driving tests. AI cars are runtime children of the main scene, so restarting the
scene creates a fresh pair. R resets only the player; the AI continue circulating.

## Validation

`tools/validate_ai.gd` runs 180 simulated seconds, checking both departures, 80 km/h
compliance, acceleration after the limit, merge completion and repeated circuits.
The initial run reached the race line at roughly 34 and 41 seconds, completed over
four full circuits thereafter, and stayed within approximately 1.3 m of the line.
These are automated empty-track results, not a guarantee for arbitrary player traffic.

`tools/validate_ai_traffic.gd` checks departure blocking, the merge-gap decision,
following speed and AI camera switching. Existing practice and driving regression
checks also pass. `tools/capture_ai.gd` renders the assigned cars in their boxes.
