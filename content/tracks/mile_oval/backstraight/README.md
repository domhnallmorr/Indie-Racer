# Back-straight scenery

Track-local decorative geometry, visible in editor and game. The bank starts 2 m outside the racing wall's outer face, rises to 2 m over a 5 m wide profile, and tapers over 10 m at each end. A 3.2 m concrete perimeter wall with panel seams and caps runs along the full 412 m back straight at Z=-144. Ten 13 m wooden utility poles sit 2 m beyond it, with crossarms, insulators and three cables sagging 1 m per span.

No driving-surface or collision changes. This models the described back-straight section, not a surveyed reconstruction or a wall around the other three sides of the facility.

The bank, perimeter wall and power lines continue around turn 3 to 15 m beyond its 90-degree arc (measured along the 125 m reference radius). The bank joins the straight at full height and tapers over the final 10 m. Curved wall panels retain the 144 m setback; six additional poles follow the 146 m radius, with radial crossarms and sagging wire spans connected to the existing corner pole. `builds/turn3_boundary_extension.png` is the outside-corner capture.

`camera_platforms.gd` adds three static TV camera towers on clear infield grass at (X,Z)=(-145,-81), (-15,-46) and (145,-81) m, facing the back straight. The end towers sit inside the inner wall; the middle tower is set farther back to avoid the central RV camp and the infield roads. Each has a 5.7 m raised deck, braced scaffold legs, guardrails, rear access ladder, numbered TV fascia, tripod-mounted broadcast camera and an operator holding the pan handles. Geometry and shared materials match the existing low-poly scenery and support runtime static batching. Capture the result with `tools/capture_camera_platforms.gd`.

`material_atlas.png` was generated using built-in imagegen. Three equal strips contain grass, concrete and timber. The shader tiles the selected strip in world space; the original generated image is retained without processing.

## Generation prompt

Use case: stylized-concept. Game texture atlas for a late 1990s racing simulator. Square image divided into exactly three equal vertical strips, no gutters or borders. Left third: seamless top-down short olive green grass turf with subtle brown flecks, low detail, flat diffuse lighting. Middle third: seamless weathered light grey poured concrete wall surface, subtle aggregate and stains, no perspective, no joints or objects. Right third: seamless weathered brown timber utility pole wood, straight vertical wood grain, subtle cracks. All strips fill entire image height. Each strip is a separate tileable material. Restrained low-resolution 1990s game textures, coarse detail, no highlights, shadows, text, labels, logos or objects. Flat texture sheet only.

## Verification

`tools/capture_backstraight.gd` checks bank height, pole setback and the shifted turn 3 hoardings, then captures three game views. The turn 3 set moved exactly 200 m along the reference path, from -140 m to +60 m relative to turn 3 entry.

