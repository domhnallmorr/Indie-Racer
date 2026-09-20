# Oval Racer

A Godot 4 single-player oval racing project. Initial scope: simple but expandable
simulation physics, a full AI field, and one flat oval inspired by Milwaukee Mile.
Low-poly, mid-to-late 1990s presentation. Races include fuel stops and
[full-course cautions](docs/cautions.md), with pace-car pickup and single-file restarts.

## Layout

```text
content/
  tracks/<track_id>/
    manifest.json       Identity and relative entry-scene path
    scenes/             Track geometry, collision, spawn positions
    models/             Exported models (.glb preferred)
    textures/
    materials/
    ai/                 Racing line and track-specific AI data
  vehicles/<vehicle_id>/
    manifest.json       Identity and relative entry-scene path
    scenes/             Vehicle assembly
    models/
    textures/
    materials/
    audio/
    physics/            Vehicle-specific tuning data
    liveries/           Paint schemes shared by player and AI cars
game/
  main/                 Application entry point
  content/              Content discovery and loading
  vehicle/              Shared vehicle controller and physics code
  ai/                   Opponent driving and decision-making
  race/                 Grid, timing, laps, positions, race state
  camera/               Driving and replay cameras
  ui/                   Menus and HUD
shared/                 Reusable materials, textures, audio, and fonts
source_art/             Blender working files, excluded from Godot import
docs/                   Content conventions and design notes
tools/                  Future content preparation utilities
builds/                 Local exports (ignored by Git)
```

Content packages own their assets and tuning. Shared gameplay code stays in
`game/`, so physics and AI improvements apply across packages. Driver rosters and
race sizes can be added with the race system; they are not tied to vehicle models.
Player and AI should eventually use the same vehicle physics with different inputs.

## Open the project

Import `project.godot` in Godot 4.7.2 and press F6 on the main scene or F5.
The startup scene begins a [60-minute practice session](docs/practice.md) with the
car in a text-configured pit box. [WASD driving](docs/driving.md) is available with an
80 km/h pit limiter that ends before Turn 1. Keys 1/2/3/4 select overview, pits,
banking, or the car; 5 returns to the cockpit. Exterior views use right-drag orbit
and wheel zoom. T selects an automatic TV trackside view; numpad + / - cycles through
the cars in their current order around the circuit. See [cockpit controls](docs/cockpit.md), [Mile Oval](docs/mile_oval.md)
and [Open Wheel 95](docs/open_wheel.md) for Blender workflows and dimensions.
[Player bicycle physics](docs/player_physics.md) now supplies tyre slip, aero and
six-speed gearing from separate CFG files. W accelerates, S brakes, V selects reverse
while stopped; Q/E shift and M toggles automatic shifting. Press 8 for physics debug.
The player has a synthesized V8 engine tone driven by physics RPM and throttle,
so neutral revving, shifts and limiter behaviour are audible in every camera.
Adjust `EngineAudio.engine_volume_db` in the player vehicle scene to change its volume.
The [two AI opponents](docs/ai.md) retain their basic controller. They leave assigned
pit boxes, respect the limiter and join the racing line; keys 6/7 follow them.
Press **9** for [practice timing](docs/timing.md): positions by best lap, last laps
and completed timed laps for the player and both AI cars.

## Adding content

See [the content guide](docs/content_packages.md). The included `mile_oval` is an
importable track; `open_wheel` contains the prototype car. Adding another folder and valid
manifest under the appropriate content directory registers it on the next startup
or `ContentCatalog.refresh()` call; no central list needs editing.

Next milestone: tune player handling, then adapt the AI to the new physics before
developing side-by-side behaviour and passing.
