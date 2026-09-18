# Track flags

`flagpole.gd` supplies the existing infield American flag. `flag_stand.gd` supplies a separate starter's platform outside the front-straight wall, centred at X=62.49594 m on the middle of the chequered finish stripe. The 5.65 m deck clears the catchfence, with a trackward cantilever, braced steel supports, guardrails, a canopy, rear stairs and a chequered fascia. The stairs fit between the outside wall and main grandstand.

Green, yellow and chequered flags are stowed in a rear rack. This is a scenery model; active flag waving and race-state integration are not implemented. The stand sits outside the car-accessible area and has no additional collision.

`track_surface.gd` hides legacy GridSlot meshes from the imported track before visual batching. `tools/build_mile_oval.py` omits these markings on future rebuilds. Finish checks and pit-box markings remain.

Run Godot with `--path . --script tools/capture_flag_stand.gd` to check grid visibility and finish alignment and capture trackside, front-straight and rear views in `builds/`.
