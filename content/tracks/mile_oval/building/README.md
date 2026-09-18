# Pit media / medical centre

Milwaukee-inspired approximation, built by `pit_building.gd` in the editor and at runtime. The original 160 x 18 x 8 m imported placeholder is hidden and its physics body disabled. The replacement stays centred at track-local (20, 0, 58): 105.6 m long (66 percent), 18 m wide, 3.4 m eaves and 4.65 m ridge. A shallow hipped roof overhangs the walls. New box and convex roof collisions match the replacement; no invisible old building remains at the shortened ends.

Cream walls, a dark grey roof, window surrounds and mullions, glazed double doors with handles, entry canopies, media/medical signs, end service doors and vents, gutters, downpipes and a perimeter walkway provide an institutional paddock-building appearance. Shared opaque materials allow the existing static visual batcher to combine the detail meshes. Doors and windows are exterior scenery, without an interior.

The combined care/media function is documented at https://www.savethemile.com/index.php/history-of-the-mile.html. Dimensions and facade layout are artistic choices, not surveyed measurements or an exact reconstruction. No external image assets are used.

Validation: run Godot with `--headless --path . --script tools/validate_pit_building.gd`; `tools/validate_track.gd` checks road/pit collisions. Run `--path . --script tools/capture_pit_building.gd` for front, rear and overview screenshots in `builds/`.

The Blender source generator still contains the original placeholder; this scene-level replacement is applied when loading `track.tscn`, including after regenerating its imported GLB.
