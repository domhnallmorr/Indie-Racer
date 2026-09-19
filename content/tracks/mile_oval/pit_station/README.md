# Pit stations

27 stations align with all painted pit boxes, behind the infield pit wall. The 5.4 x 3.6 m canopies and equipment stay inside z=86.75, leaving the service apron clear. PitStations in track.tscn creates reusable stations at the same spacing as tools/build_mile_oval.py. No extra collision bodies. Occupied stations match car colours using assigned pit box IDs, including race-grid ordering. Unoccupied stations use a varied palette.

Three CRT-style timing screens show illustrative static data, not live telemetry. Three transparent crew sprites use vertical-axis billboards; they are static photographic cutouts, not animated people. Equipment is native Godot geometry and participates in the existing static batching. Crew remains separate.

Run tools/capture_pit_station.gd for the detail, driver-height approach and equipment views. Checks cover all 27 stations, 81 crew sprites, spacing, apron clearance and matching colours for the active roster. Alternate layouts reflect equipment with corrected triangle winding for static batching. Crew frames and positions vary deterministically; the approved player station remains the first layout. Materials and the sprite atlas are shared across stations.

crew.png was generated with the built-in image_gen tool, then copied into this directory with transparency preserved. Timing graphics are code-authored SVG.

## Final image prompt

Create a production game asset: one wide transparent PNG sprite sheet with THREE separate full-body photorealistic early-2000s American open-wheel racing team engineers, equal spaced in three columns with ample transparent gaps. All feet visible and aligned on same baseline, no cropping. Left: standing male engineer holding clipboard, red short sleeve team shirt, black trousers, black shoes, black radio headset, three-quarter view facing slightly right. Middle: standing female engineer wearing same uniform and headset, arms naturally bent typing at an unseen waist-high desk (do not draw desk), three-quarter view facing slightly left. Right: standing older male crew chief same uniform, headset, folded arms looking toward track, near frontal view. Real adult anatomy and realistic cloth, understated natural expressions, soft diffuse daylight, neutral even exposure. No helmets, no logos, no text, no furniture, no ground plane, no cast shadows outside bodies. Truly transparent alpha background. These will be cut into individual 2D game billboards; each complete person must be isolated, distinct and nonoverlapping. High detail photographic cutouts, not cartoon or illustration.

