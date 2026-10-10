# Indianapolis Motor Speedway

Select **Indianapolis Motor Speedway** in Weekend Setup. The content catalog
automatically discovers this package. Reference length is 4023.36 m (2.5 miles).

The user's `ims2000/Ims2000.dat` supplies the TRK plan geometry; `RACE.LP`,
`MINRACE.LP` and `MAXRACE.LP` supply the racing groove and lateral bounds.
Source hashes and transformations are recorded in `source.json`. Original game
textures and scenery are not included.

| Section | Banking | Racing width |
| --- | --- | --- |
| Each of the four turns | Up to 9.266607 degrees | Up to 60 ft / 18.288 m |
| Short chutes | About 4.214 degrees at their midpoints | 50 ft / 15.24 m |
| Long straights | 0 degrees away from transitions | 50 ft / 15.24 m |

Widths are horizontal, excluding the apron. A **provisional 12 ft / 3.6576 m
flat apron** is provided throughout; the user supplied no Indianapolis apron
dimension. The inner racing edge anchors the bank at ground height.

Banking follows the user's extracted ICR2 `banking_profile.csv`, with linear
interpolation between its 1,582 samples. Source distances are scaled from
13,200.3335 ft to the track's 4,023.36 m lap, matching the TRK plan scaling.
This includes the wider full-bank plateaus, banked short chutes, and slight
negative entry camber (minimum about -0.1573 degrees). The source CSV and its
SHA-256 hash are preserved in the package and `source.json` for reproducible builds.
Horizontal width changes retain the existing 220 m quintic transitions,
starting 40 m before turns and ending 40 m after them. The flat apron remains
anchored to the inner racing edge. Visual and collision geometry share the
same approximately 2 m samples, and AI reference/groove/corridor heights are
regenerated from that banking.

MIN/MAX bounds map to car-centre limits 1.7 m from each road edge. RACE preserves
its relative lateral position between those limits, with 12 m smoothing. Passing
lanes are newly authored and maintain the controller's required separation.
Imported speeds are retained (reference lap about 39.172 seconds). Roster-relative
driver variation uses the existing anchor; player pace and gearing still need
driving feedback.

The initial package includes walls, catch fencing, timing gates, a two-wide grid,
26 pit boxes and a pace-car box. The authored adjacent pit road follows the
frontstretch and continues through turns 1/2 to a backstretch merge. The pit
limit is 80 km/h. Paved access covers the AI's entry and exit blends.
The 17 m pit pavement now sits beside the apron with a 0.55 m concrete divider,
removing the frontstretch grass gap. Boxes move 14.5 m toward the straight.
The pit wall is 1.05 m high, starts 290 m after Turn 4's geometric exit,
and ends 25 m before Turn 1, while the pit route
continues through Turns 1/2. A continuous inner wall follows the infield edge
of the apron/pits, with open entry/rejoin routes. After Turn 2 the inner wall
holds its infield offset along the entire backstretch, leaving the grass intact;
it blends back to the existing inner boundary through Turn 3.
A roughly 30 m scoring pylon sits on the divider 75 m after start/finish.
Its two faces show decorative position numbers, not live race standings.
These placements use the supplied photograph as an approximate visual reference.
Grandstands now include 16 approximate IMS sections: covered Paddock/A/B/E
stands, open C/H/J stands, the southwest/south/southeast and
northeast/north/northwest vistas, plus Tower Terrace and Pit Road Terrace.
They have stepped seating, the project's shared crowd atlas, aisle steps,
railings, open steel supports and canopy trusses. The east backstretch retains
the large gap shown on the reference map. The infield terrace fronts sit 43 m
inside the racing edge, clear of the authored pit road and boxes.

Placement and canopy grouping are reference-inspired approximations, not a
surveyed replica or an exact reconstruction of the 2000 seating configuration.
Row counts, heights and individual bay dimensions are authored for this project.
References consulted on 29 September 2026:

- [IMS official race-day map](https://www.indianapolismotorspeedway.com/-/media/IMS/maps/gate-stands/2026/pdf/9_I500_Race-Day_Gate.pdf)
- [IMS official stand guide](https://www.indianapolismotorspeedway.com/-/media/IMS/pdf/2025/Seasonal_staff/power_point/2025_stands_mounds.pdf)
- [IMS maps and seating viewer](https://www.indianapolismotorspeedway.com/events/indy500/plan-ahead/maps-hub)

The stands are procedural scenery in `grandstands.gd`, visible both in the
editor and at runtime. Geometry is grouped by stand/material for batching
(about 258k triangles). They add no physics collision bodies. The track generator
does not overwrite this scenery. The shared skyline remains; garages and
other Indianapolis buildings are not yet modelled.

The photo-inspired Pagoda in `pagoda.gd` is aligned with start/finish behind
the pit lane, in the gap between the terraces. Five glazed storeys have stepped
canopies, exposed steel supports, balcony rails, timing fascia and roof flags.
Its proportions are approximate. Material-batched scenery adds no road collisions.
The finish marking is now a 0.9144 m Yard of Bricks spanning the racing surface,
apron and full pit pavement, centred on the existing timing line. Staggered brick
and mortar detail comes from `bricks.gdshader`; the overlay adds no physical bump.

`turn2_suites.gd` adds the Turn 2 VIP Suites centred at the Turn 2 exit,
with Southeast Vista shortened to clear the building. Its approximate 135 m exterior includes a service
base, three glazed suite/balcony levels, white chairs, pale railings, end cores
with glazed stair strips, and a flat overhanging roof. Dimensions and placement
are fitted to this track, not surveyed. Nine material batches add no collisions.
References: the supplied Google Maps screenshot, the
[IMS suite listing](https://www.indianapolismotorspeedway.com/events/grandprix/hospitality/turn-2-vip-suites)
and [exterior/balcony photos](https://www.indymotorspeedway.com/standmap_T2_Suite.html)
(consulted 30 September 2026). `capture_indianapolis_pits.gd` also checks the
scenery batches and saves `tmp/indianapolis_suites*.png` from infield/track level.

`backstretch_trees.gd` places 51 golf-course trees outside the backstraight,
between the Turn 2 suites and Northeast Vista. Trunks sit roughly 30 m behind
the outer wall (27–33 m, with occasional companions 6 m farther back).
Deterministic spacing, rotations and sizes vary ten shared tree types from the
mile-oval tree library, rendered in ten MultiMesh batches without collisions.
The capture script verifies the tree count and saves
`tmp/indianapolis_backstretch_trees.png` for visual review.

Rebuild and verify from the source directory:

```powershell
python tools/build_indianapolis.py 'C:\path\to\ICR2\TRACKS\ims2000'
python tools/validate_indianapolis_geometry.py
godot --headless --path . --script tools/validate_indianapolis.gd
godot --path . --script tools/capture_indianapolis.gd
godot --path . --script tools/capture_indianapolis_grandstands.gd
```

Validated with Godot 4.7.2: requested widths, apron dimensions, closed seams,
AI clearance, collision banks in all four turns, flat long straights,
formation reaching green, two AI cars completing laps, and pit service
followed by rejoin. The preview capture saves overview and banking images in
`tmp`. Full-field endurance and player handling calibration remain untested.
The sandbox run also reports unavailable player telemetry output and engine
certificate-store/shutdown warnings; these do not fail the track checks.

The generator writes data only; the scene and renderer are hand-authored.

Banking update (10 October 2026): replaced the authored banking ramps with
the supplied ICR2 profile. All 2,013 road cross-sections match the interpolated
CSV within 0.000021 degrees. Road/AI horizontal coordinates and imported speeds
are preserved. AI corner marker heights follow the rebuilt groove. Godot
collision probes confirm the four turn plateaus and both banked short chutes.
The runtime check covers formation, two AI cars completing laps, pit service,
and rejoin; the banking preview was rendered and visually reviewed.

Grandstand validation: rendered the integrated scene with static batching,
checked all 16 sections and absence of added collision bodies, and visually
reviewed frontstretch, track-level, north/south vista and overview captures.
Images are saved as `tmp/indianapolis_stands_*.png`.

Runtime road collision optimization (10 October 2026): `road_collision.gd`
reduces straight, level eight-quad ribbons to two triangles where their edges
are collinear within 0.1 mm and area/winding checks pass. It uses the mesh's
actual collision vertices. Other strips retain their original faces, including
all 18,910 banked/transition triangles. The road collider falls from 32,192 to
25,892 triangles; the visible mesh, apron, pit road and barriers are unchanged.
`tools/validate_indy_road_collision.gd` checks 40,240 support/edge rays against
the original collider. See `docs/indy_practice_profile_2026_10_10.md` for timing
results and the repeatable exported-game benchmark.

Pit-layout validation (30 September 2026): geometry checks pass for continuous
paving, wall dimensions/seam and pylon placement. The runtime probe passed
formation, two AI cars completing laps, pit service and rejoin. Visual captures
from `tools/capture_indianapolis_pits.gd` are saved as `tmp/indianapolis_pits_*.png`.
