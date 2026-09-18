# Mile Oval prototype

The source is `source_art/tracks/mile_oval/mile_oval.blend`; Godot imports
`content/tracks/mile_oval/models/mile_oval.glb` through `scenes/track.tscn`.
Press F5 for the track viewer: right drag to orbit, wheel to zoom, and 1/2/3
for overview, pit lane, and corner banking views.

## Dimensions and layout

All geometry uses metres (one Blender/Godot unit = one metre). Future physics
uses kilograms and seconds, with speeds displayed in km/h (m/s multiplied by 3.6).
The stadium oval's horizontal reference centreline is 1609.344 m long, with
125 m corner radii and approximately 411.973 m straights. Actual driving distance
depends on line choice and elevation. This is an interpretation of Milwaukee,
not surveyed track geometry. INDYCAR describes the real circuit as a one-mile
oval with nine-degree corners:
https://www.indycar.com/Schedule/2026/Milwaukee-Race1

- Racing surface: 20 m horizontal width, 9° maximum corner banking.
- Banking eases over 100 m at either end of each semicircle; straights are flat.
  A quintic easing curve gives zero slope and curvature at the flat and fully
  banked ends, softening both corner entry and exit.
- Apron: 6 m, flat and continuous, connected at the racing surface's inner edge.
- Outer wall: 1.15 m high, 0.5 m thick. Continuous inner wall encloses the infield.
- Pit entry: after T4, gradually splitting inward along the front straight.
- Pit lane: 10 m wide at full width, 27 marked boxes on its infield side.
- Pit exit: follows the inside of T1 and T2, then tapers into the backstraight
  apron. The separator wall ends before the merge taper.
- Start/finish checks, a raised starter's flag stand, grandstands and a pit building. Standing-start grid marks are omitted for rolling-start oval racing.

Roads, apron, pit pavement, ground, buildings and walls use static mesh collisions
through Godot's `-col` import suffix. Paint and other decoration have no collision.
The track scene has a player spawn facing the counterclockwise direction.
Reference and pit paths in `ai/reference_paths.json` use Godot coordinates;
these are geometry references, not completed racing AI or pit-stop logic.

## Editing and rebuilding

Edit the Blender mesh directly and export selected runtime meshes as glTF Binary
to the GLB path above (exclude the overview camera). Keep transforms applied,
glTF's default +Y-up export, and the collision name suffixes. Godot reimports it.
Keep gameplay markers and scripts in the wrapper `.tscn` so reexports preserve them.
After manual layout edits, update reference paths and spawn markers accordingly.

For a parameter-based rebuild, run in PowerShell from the project folder:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/build_mile_oval.py
```

This overwrites the generated Blender file, GLB, paths and overview. Save manual
Blender edits under a different filename before regenerating. The generator checks
reference length, banking, closed seams and upward road normals.
`tools/validate_track.gd` checks imported collisions along the road and pit paths.
Vehicle handling, physical driving tests, pit operations, AI and track limits remain
future work. Geometry sampling is approximately 2 m; refine if driving tests reveal bumps.
