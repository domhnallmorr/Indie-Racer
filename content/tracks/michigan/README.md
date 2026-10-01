# Michigan International Speedway

Select **Michigan International Speedway** in Weekend Setup. The content catalog
discovers this package automatically. Track length is 3218.688 m (two miles).

The user's Michigan ICR2 `MICHIGAN.DAT` supplies the plan geometry; `RACE.LP`,
`MINRACE.LP` and `MAXRACE.LP` supply the racing groove and its lateral bounds.
LP files alone do not contain an XY track layout. Source hashes and transformations
are recorded in `source.json`; no original game textures or scenery are included.

| Section | Banking | Racing width | Additional apron |
| --- | --- | --- | --- |
| Turns 1/2 and 3/4 | 18 degrees | 73 ft / 22.2504 m | 10 ft / 3.048 m |
| Frontstretch | 12 degrees | 45 ft / 13.716 m | 12 ft / 3.6576 m |
| Backstretch | 5 degrees | 45 ft / 13.716 m | 12 ft / 3.6576 m |

Widths are horizontal dimensions, with the apron additional to the racing road.
The inner racing edge anchors the bank at ground height. Aprons are flat.
Banking uses Texas's 360 m quintic transitions, starting only 40 m before the
geometric turns. Maximum banking is reached about 320 m into each turn.
Exit ramps smoothly reach the next straight's banking 40 m beyond the turn.
Road and apron widths blend over the same transitions. Physics and visuals use
the same sampled surface, including the start/finish seam.

The supplied MIN/MAX bounds map to car-centre limits 1.7 m from each road edge;
RACE preserves its relative position between those bounds, with 12 m lateral
smoothing. Newly authored passing lanes maintain at least 5 m separation.
Imported LP speeds are retained (reference lap about 30.825 seconds). Driver
differences use the existing roster anchor; player pace/gearing calibration is
still provisional and should follow driving feedback.

The initial package includes outer walls, catch fencing, timing gates, a two-wide
grid, 26 pit boxes and a pace-car box. The authored inset pit road continues
through turns 1/2 to a backstretch merge. Pit speed limit is 80 km/h.
Scenery is a basic grass setting with the project's shared environment; detailed
Michigan grandstands and buildings are not yet modelled.

Rebuild from the original source directory:

```powershell
python tools/build_michigan.py 'C:\path\to\ICR2\TRACKS\MICHIGAN'
python tools/validate_michigan_geometry.py
godot --headless --path . --script tools/validate_michigan.gd
godot --path . --script tools/capture_michigan.gd
```

The runtime validator probes banking collisions, AI profile readiness, formation,
lap completion, pit service and rejoin. The capture saves overview/banking images
to `tmp`. The generator writes data only; the scene and renderer are hand-authored.
