# Practice session

F5 starts a 60-minute practice session automatically, with the player in the first
configured pit box and the cockpit camera selected. The HUD shows remaining time,
pit-lane state and the assigned box. At zero it displays SESSION COMPLETE and the
clock stops. No automatic transition, qualifying rules or race rules exist yet.
Basic WASD driving and the pit limiter are described in `docs/driving.md`. Speed is
live; other cockpit telemetry remains placeholder data. Session time follows Godot process time and pauses with
the scene tree (there is no pause menu yet).

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
