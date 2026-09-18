# Dallara IR-05 — Oval

The exterior is adapted from ccjr's Dallara IR-05 STL, supplied by the project owner. Attribution and licence-verification status are in `content/vehicles/open_wheel/ATTRIBUTION.md`.

The source body silhouette is preserved. Road-course wing assemblies are replaced with thinner, smaller single-element oval wings: front span 1.62 m/chord 0.32 m; rear span 1.08 m/chord 0.36 m. Both have smaller endplates and new supports. These dimensions are visual approximations based on the supplied oval-racing references, not a certified factory aerodynamic specification.

The source's coarse wheels are replaced with smooth slicks, recessed rims and separate hub pivots. Mesh cleanup merges coincident vertices and removes degenerate faces; smoothing preserves sharp creases. This retains the source mesh's angular body contours rather than inflating or subdividing them into rounded shapes.

- Archived original: `source_art/vehicles/dallara_ir05/Dallara_IR05_original.stl`.
- Working source: `source_art/vehicles/dallara_ir05/ir05_oval.blend`.
- Runtime: `content/vehicles/open_wheel/models/open_wheel.glb`.
- Approximately 5 m long, 2 m wide and 1 m tall; 3 m visual wheelbase.
- Blender +Y forward exports to Godot -Z forward and +Y up; origin at ground level.
- Four `WheelFrontLeft/Right` and `WheelRearLeft/Right` objects retain hub origins and parented rims. Wheel spin axis is local X.
- Fourteen painted parts share a non-mirrored `LiveryUV` atlas. The primary `Livery_RacingRed` name is retained for roster recolouring.
- Existing tuned physics and collision shape remain unchanged. The vehicle Visual node provides a cockpit offset to align the existing instruments and eye position with the imported cockpit.

## Rebuild

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/build_ir05_oval.py
& 'C:\Users\domhn\Documents\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --editor --quit
& 'C:\Users\domhn\Documents\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe' --path . --script tools/capture_car_2001.gd
```

The IR-05 builder reuses material, wheel, UV and export helpers from `tools/build_open_wheel.py`, but not that script's generic body. Do not run the old builder to update the current car: it generates the superseded generic model. The IR-05 builder deterministically classifies the archived STL's loose parts; a different source file requires re-auditing this mapping.

Rebuilding overwrites the derived GLB, working source, paint template and studio previews. It preserves the archived original STL. Finish geometry edits before painting final liveries, since UV packing may change. See `content/vehicles/open_wheel/liveries/README.md` for the template and per-car skin helper.

`tools/capture_car_2001.gd` retains its historical filename and verifies the current asset: dimensions, wheelbase, oval wing dimensions, UVs and texture replacement isolation. It captures three runtime views and a checker skin. `tools/capture_cockpit.gd` verifies the actual driving view, camera switching and mirror update states. Neutral silhouette previews are `source_art/vehicles/dallara_ir05/oval_grey.png` and `oval_grey_side.png`.
