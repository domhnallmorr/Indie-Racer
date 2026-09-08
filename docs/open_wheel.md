# Open Wheel 95 — Oval

Car for Godot **4.7.2**, with a low-poly mid-1990s racing-game look.
Generic design, red/ivory material livery, shallow-chord single-element oval wings,
16-sided slick tyres, exposed wishbones, open cockpit and a simple helmeted driver.
The wrapper now adds a CharacterBody3D, collision and basic WASD driving. See
`docs/driving.md`. Suspension and engine simulation remain future work.

- Source: `source_art/vehicles/open_wheel/open_wheel.blend`.
- Runtime: `content/vehicles/open_wheel/models/open_wheel.glb`.
- Wrapper: `content/vehicles/open_wheel/scenes/vehicle.tscn`.
- Dimensions: approximately 4.52 m long, 2.04 m wide, 0.98 m tall; 2.82 m wheelbase.
- One unit = one metre. Blender +Y forward exports to Godot -Z forward, +Y up.
- Model origin is ground level. Four wheel objects have origins at their hubs;
  rim objects are parented to the corresponding tyres. Wheel spin axis is local X.
- Practice places the car in the first configured pit box, facing pit-lane direction.
  F5 starts in the cockpit (see `docs/cockpit.md`). Right drag orbits in exterior
  views; wheel zooms; 4 returns to the car exterior and 5 to the cockpit.
  1/2/3 still select overview, pits and banking.

Edit the `.blend` and export selected runtime objects to the GLB path. The saved
selection excludes `PreviewGround` and `PreviewCamera`; keep those out of exports.
Use default glTF +Y-up conversion, and preserve object names and metric scale.
Livery materials can be edited directly; UV textures and a livery selection system
are not implemented yet.

Rebuild from the project folder with:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.1\blender.exe' --background --python tools/build_open_wheel.py
```

Rebuilding overwrites the generated source, GLB, preview and statistics; save any
manual modelling changes separately first. The overview is a Blender render.
The project targets Godot 4.7.2. On this machine the executable found and used for
validation is `C:\Users\domhn\Documents\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`.
