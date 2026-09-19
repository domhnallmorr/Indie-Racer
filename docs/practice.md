# Practice session

F5 starts a 60-minute practice session automatically, with the player in the first
configured pit box and the cockpit camera selected. The HUD shows remaining time,
pit-lane state and the assigned box. At zero it displays SESSION COMPLETE and the
clock stops. F12 opens the combined session/roster panel, where a 10-lap rolling-
start race can be selected.
Basic WASD driving and the pit limiter are described in `docs/driving.md`. Speed is
live; other cockpit telemetry remains placeholder data. Session time follows Godot process time and pauses with
the scene tree. The compact driving HUD only shows session, pit and essential
vehicle/spectator state. F12, 9, F10 and 8 open the Session, Timing, Controls and
Diagnostics screens in the shared race UI; selecting the active screen, choosing
Drive or pressing Escape returns to the track. Player driving input is suspended
while the UI is open, while the session clock and AI continue.

## Text-file pit-box placement

Edit `content/tracks/mile_oval/session.json`. Positions use track-local Godot
coordinates in metres: X right, Y up, Z back. `heading_deg` is rotation about +Y;
zero faces -Z and -90 faces +X, the front-straight race direction.

```json
{
  "id": "player_pit_01",
  "position": [-81.04, 0.025, 92.75],
  "heading_deg": -90.0
}
```

This is inside the first painted pit stall. The 0.025 m height clears the ground
at spawn. Three boxes are assigned in data: player, blue AI and yellow AI, using
the first three of 27 painted stalls. See `docs/ai.md` for departure behaviour.
Track transformations are applied to these local coordinates.
The old PlayerSpawn marker in the track scene is not used for practice.

## Runtime state

Practice cars start parked with their engines off. The cockpit LCD shows Tyres,
Fuel, and Leave Pits, with Fuel selected initially. Up/down selects a row and
left/right selects a 5–35 US-gallon fuel load; Enter on Leave Pits starts the
engine and enables driving. Fuel is live for the player: the 35-gallon tank holds
132.5 L of methanol-equivalent fuel, adding up to 105 kg to the 700 kg dry chassis.
It burns continuously with distance at a nominal 60 green-flag laps per full tank.
Session panels take priority over the pit menu. After session expiry, departure
is unavailable. The practice clock continues while parked.

Returning within 1.2 m sideways and 2 m longitudinally of the assigned stall,
within 15 degrees of its heading and below 1 km/h for 0.35 seconds, parks the
player again. Leaving inhibits this detection until the car clears the stall.
R also returns the player to a parked, engine-off state in practice.
AI uses its existing arrival and departure schedule with the same engine state.
Race driving is unchanged; `PlayerState.StallState` reserves SERVICING for future
pit-stop rules, independently of the session and pit-lane state.

- `Session.session_type`: PRACTICE, with QUALIFYING and RACE reserved enum values.
- `Session.practice_duration_seconds`: 3600 by default; editable on the main
  scene's Session node. `remaining_seconds` counts down and clamps at zero.
- `Session.status`: NOT_STARTED, RUNNING or FINISHED; emits `finished` once on expiry.
- `DisplayCar/PlayerState.is_in_pit_lane`: boolean recalculated each physics frame.
- `DisplayCar/PlayerState.pit_lane_changed`: signal emitted only when that state changes.
- `DisplayCar/PlayerState.assigned_pit_box_id`: box assignment, not a claim that the
  car is currently stopped in that box.

The lane test uses the car origin in track coordinates. It includes a 5 m corridor
on each side of the existing pit reference path (entry, front straight, T1/T2 bypass,
backstraight merge), plus the configured X/Z polygon over the pit stalls. The height
range prevents unrelated objects above/below the lane from being classified inside.
This first-pass region is intentionally full width at the tapered entry/exit and
has rounded end caps; it is not yet a regulatory pit-speed enforcement boundary.
A separate pit-speed polygon now ends before T1; see `docs/driving.md`. The full
exit route remains part of the pit-lane region without being speed limited.

Track lane/spawn configuration is separate from session rules and player state.
Include this JSON and the referenced path JSON when making an export, along with
the other track manifests. See `docs/content_packages.md` for export limitations.

Validation: `tools/validate_practice.gd` checks startup, heading, duration/expiry,
lane membership and transitions, ground collision and mirror repositioning.

## Rolling-start race

A race places the player and roster in a two-wide grid on the back straight. The
field starts one formation lap at 80 km/h, with 8 m between car centres in each
lane and 5 m between lanes. AI cars hold their formation groove until the lead AI
passes the configured release point after Turn 4, then normal pace and racecraft
take over. The player is never speed-limited or position-controlled by the start
procedure.

The first start/finish crossing after green begins lap 1. The session finishes
when the first car completes ten laps. Race standings rank completed laps first,
then checkpoint progress; practice continues to rank best laps. Grid dimensions,
pace speed, lap count and the green point live in the track's `session.json`.

Validation: `tools/validate_race_session.gd` checks grid geometry, formation mode,
the Turn 4 green release, unrestricted player control and the ten-lap finish.

## AI practice pit cycles

Each AI draws an initial departure delay of 0–7 minutes, then runs 6–20
completed timed laps before taking the next pit entry. The out-lap does not count
towards the run. Cars follow the last corners, brake into the pit lane and return
to their assigned box. Once stopped, they wait a fresh random 4–10 minutes and
start another randomly sized run. The roster seed also makes these choices
repeatable. Session expiry prevents further departures and calls circulating cars back
at the next pit entry. Select an AI with 6/7 to see its run target or box countdown.

AI cars ignore car collisions while parked, entering the pits and following the
pit-exit route, including the merge. Ground and wall collisions remain active.
Car collisions resume at the end of the exit route, outside the pit-lane region;
the existing merge traffic check remains active. Racing AI ignore ghosted cars
in their traffic planning. Race sessions do not use the practice run schedule.

`tools/validate_practice_pits.gd` exercises departure, entry, assigned-box stopping,
dwell and repeat departure, including collision exceptions and their restoration.
Pass `-- --bicycle` for the bicycle AI or `-- --natural` for six actual timed laps
and a return to the last AI box. The default test advances the lap eligibility
and dwell deadline to exercise the full driving cycle quickly.


## Qualifying and the race grid

Choose **Qualifying — 10 minutes** on Race Weekend. Qualifying uses practice's
pit controls, AI departure schedule (the opening seven minutes), stint cycles
and valid-lap timing. At 00:00 it immediately returns to Race Weekend; laps still
in progress do not count. Results show each driver's fastest completed lap.
**Go to Race** uses this order for every grid slot, including the player. Equal
times retain entry order; drivers without a timed lap start behind timed drivers.
Skipping qualifying retains the default roster grid. The pole sitter, including
the player, triggers green when crossing the configured formation release point.

The roster, session seed, race length and race fuel capacity carry between
sessions. Starting qualifying again replaces its previous result. Continuing
from weekend setup starts a fresh weekend. Use **F12 > Session > Return to Race
Weekend** to leave practice and choose qualifying. Leaving qualifying early does
not save an incomplete classification.

Validation: `tools/validate_qualifying.gd` checks the clock, pit controls, AI
schedule, classification, automatic menu return, retained settings, grid and
player-led green flag.
