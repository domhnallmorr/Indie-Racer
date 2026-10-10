# Surfers Paradise — CART 1995

An experimental street course for the oval racer. Select **Surfers Paradise —
CART 1995** in **Race Weekend**, then choose **Private Testing**, **Practice**,
**Qualifying** or **Race**. Private Testing is the quickest way to explore it.
The player starts with the road aero package and 14° wings unless a saved setup
exists for this track. Normal pit, gearing, steering and camera controls apply.

## What was imported

The package now follows the user-supplied scratch-built **Surfers** version,
replacing the stock **AUSTRAL** geometry used for the first experiment.
Its `RACE.LP`, `MINRACE.LP`, `MAXRACE.LP` and `PIT.LP` contain **1,356 records**
each. LP data gives lateral offsets and speeds, not an XY map. The adjacent
`Surfers.dat` supplies `surfers.trk`: **87 straight/arc sections**, imported at
native scale for a **4,509.571 m** reference lap. The generated road uses 2,255
intervals, approximately two metres each. Source start/finish and direction are
preserved. The existing menu name and saved car-setup key are retained.

Compared with the old 4,498.457 m / 96-section stock version, this changes the
first two chicanes, northern turns, beachfront alignment and chicane sequence,
and southern complex. Barriers, kerbs, collision mesh, corner regions, braking
boards, timing gates, pit route and scenery positions are regenerated together.
New LP offsets are interpreted against the new TRK, never against the old road.
This follows the supplied custom model; it does not independently establish
which version is more historically accurate. The supplied folder did not
include an author credit/readme identifying the scratch-built track's creator.

The existing project decoder uses the format documented by
[SK Chow's ICR2 tools](https://github.com/skchow03/icr2tools). Source SHA-256
hashes and the precise derivation are recorded in `source.json`.

## Authored parts and limitations

- Flat road elevation. Widths are inferred from the MIN/MAX car-centre limits,
  with 1.9 m edge clearance and the existing 13.6 m minimum. The rebuilt road
  ranges from 13.2 to 15.04 m after the local second-chicane revision described
  below. These are not surveyed road edges.
- Concrete barriers, red/white kerbs, fencing, distance boards, finish
  gantry, grandstands, palms, beach, ocean and stylised hotels are newly authored.
  The city is an approximation, not a building-by-building 1995 reconstruction.
- The relevant PIT.LP segment seeds a separate service lane. It is shifted
  inward to accommodate 26 numbered stalls and a pace-car bay. Entry/exit
  openings, pit divider and an 80 km/h limiter are included. The source TXT
  describes 28 cars; this adaptation retains the game's 26 stalls plus pace bay.
- Original RACE speeds are retained in `imported_speed_mps`. Active AI speeds
  have a conservative curvature envelope covering both passing lines, plus
  braking and acceleration limits. The integrated reference is approximately
  126.0 s, versus 144.5 s for the stock-source build. The same speed-envelope
  rules are used; this is experimental circulation pace, not a historical target.
- Original assets and source LP/DAT files are not copied into the repository.
  Generated JSON and procedural geometry are sufficient to play.

The street package opts into physical corridor widths, so passing/formation
offsets use actual metres on its changing-width road. Existing oval packages
retain their prior coordinate convention. Steering lookahead is authored in
the street AI profile; the other tracks retain their existing defaults. Street
AI also projects progress onto its selected passing line through tight bends,
avoiding a steering target that falls behind a correctly positioned car.

## First-chicane photo pass

The 350–570 m section uses the user-supplied 1995 race still as a visual
reference. Its barrier envelope follows separately authored street boundaries,
with two tapered grass islands between the chicane and the barriers. Paved
recovery margins, fencing on both sides, street lane markings and grandstands
complete the local treatment. Signs and palms are kept outside the revised
envelope.

The red/cream kerbs are 1.45 m wide, with a shallow ramp to a 6 cm crown;
they have real collision and can be driven over. Grass islands have their own
collision surface and use the existing grass grip multiplier. The imported
road, AI paths/speeds, pit configuration, player physics and controls remain
unchanged. Dimensions and scenery are approximations from the photograph,
not surveyed or a claim of an exact historical reconstruction.

`tmp/surfers_t1_broadcast.png` and `tmp/surfers_chicane.png` show the result.
The pre-landscape package is saved in `tmp/surfers_before_t1_landscape/`.

## Second-chicane road revision

The user's race still and annotated game screenshot guide a deeper inside
grass island and a stronger change of direction. Between source stations
630–770 m, the road shifts laterally by up to 9 m and narrows gently to 13.2 m
at the apex. The old fast groove now crosses the grass island; it is no longer
an uninterrupted asphalt line. Low red/cream kerbs outline the island, and
independent barriers, fencing and paved margins cover the wider 600–805 m
street envelope. The exact profile is an authored approximation from the images.

The racing line, both passing paths, physical corridor, reference/pace path
and corner markers are synchronised. Main-line pace retains the player-derived
profile elsewhere, with local curvature/yaw limits and a braking/exit ramp
for this corner. The apex target is approximately 74 km/h, compared with
157 km/h in the earlier recording; this is an AI target, not a tested player
gear or maximum corner speed. The main-line override affects approximately
574–952 m including braking and acceleration. The more conservative tactical
exit ramp extends to approximately 1144 m. Original pre-edit speed arrays
are saved in the profile, making repeated rebuilds deterministic.

Use `--update-second-chicane` to regenerate this layout and its local pace
override while preserving other settings. Later scenery-only rebuilds still
use `--geometry-only`; that mode rejects a road/AI mismatch rather than leaving
stale paths. Source station indices and timing gates remain stable. The rest
of the road and the actual pit route are unchanged, as are the oval packages
and shared AI/physics code.

Geometry, corridor projections, grass grip, kerb crossing and wall collisions
pass. Physics ray probes confirm that 19 samples of the former groove hit
grass while the new groove stays on asphalt. Preview:
`tmp/surfers_second_chicane.png`. Backup:
`tmp/surfers_before_second_chicane/`.
The final two-car run completed two timed laps per car (111.07 s and 109.06 s
best), with zero wall/car contact ticks and 1.33 m peak line error. Pit service
and rejoin passed. Repeating the local-layout rebuild produced identical JSON.

## Backstraight chicane verges

The long backstraight complex at 2790–3100 m now has the same treatment:
two tapered grass verges, red/cream ramped kerbs and independent, straighter
street barriers with catch fencing on both sides. A paved recovery margin
separates the grass from the walls. Nearby palms and building footprints are
cleared away from the expanded envelope, and braking boards follow the walls.
The user’s game screenshot identifies this complex; the landscaping is an
authored approximation using the first-chicane reference, not a surveyed layout.

`tmp/surfers_backstraight.png` shows the result. The previous package and
builder are saved in `tmp/surfers_before_backstraight_landscape/`. The first
chicane's kerbs and grass are unchanged, as are all AI and session JSON files.
The landscape validator probes both complexes' grass grip, kerb crowns and
moved walls, and drives the player over a kerb onto grass in each complex.
These checks pass. The two-car practice test also completed two timed laps
each with zero wall/car contacts and 1.05 m peak line error; pit service and
rejoin passed. Barrier clearance was checked throughout the new grass zone.

## Final-turn apex verge

The user-supplied 1995 final-turn still guides a new inside verge at
3825–4028 m. The wall eases back through the tight entry arc, reaching a
13 m setback at the broader apex before tapering back on the exit, ahead
of the existing pit opening. A grass wedge follows the inside road edge,
with the same 1.45 m wide, 6 cm high ramped red/cream kerb used at the chicanes.
Catch fencing follows the moved wall, with a narrow paved margin behind the
grass. Nearby inside palms are cleared. Dimensions are an authored approximation.

The racing surface, outside wall, pit geometry and prior chicane landscaping
remain unchanged. All AI and session JSON files, including the newer
telemetry-derived pace reference, are preserved byte for byte. The landscape
validator checks the new grass grip, kerb crossing and barrier collision.
Those checks pass. The two-car circulation test completed two timed laps each
(105.08 s and 103.14 s best), with no wall/car contact ticks and 1.23 m peak
tracking error. Pit service and rejoin also passed with the preserved pace profile.
The preview is `tmp/surfers_final_turn.png`; the previous package and builder
are saved in `tmp/surfers_before_final_turn_landscape/`.

For scenery changes, use `--geometry-only` to preserve tuned AI profiles and
session data. This option requires the existing package's matching source files.

## Final-turn landmark tower

A custom white tower replaces the placeholder nearest the final-turn approach.
The user's Google Maps front and aerial screenshots supply the rounded balcony
ends, recessed glazing and repeated white fascia. The extended model has two
angled 22-storey blocks joined by a taller, blank central facade with rounded
vertical piers. Separate roof terraces and pools, a pergola and central service
roof make the two-wing footprint visible from above. The low garden wall,
hedge, broad-canopied front tree and two curved street lights remain in place.
Its frontage faces the circuit from behind the outside barrier. The modern
references inform an authored model rather than establishing the exact 1995
facade or dimensions.

`landmark_tower.gd` builds a small set of meshes grouped by material, compatible
with the existing static scenery batching. No downloaded textures are needed.
`geometry.json` stores its placement and capture camera. The road, kerbs,
grass patches, walls, AI profiles and session data are unchanged by this pass.
Previews: `tmp/surfers_landmark_view.png` and `tmp/surfers_landmark_aerial.png`.
The expanded footprint was checked for road clearance, and all driving meshes,
AI and session data remain unchanged. Previous packages:
`tmp/surfers_before_landmark/` and `tmp/surfers_before_twin_wing_landmark/`.

## Main-straight grandstands

Six separate open stands line the outside of the main straight opposite the
pits. Five are 64 m long, twice the mile oval's 32 m stand, with seating lowered
from 9 m to 7 m and the same 18 m depth. The final stand is 112 m long and
centred on the finish stripe, extending 56 m either side. It replaces the old
small stand beyond the finish. Gaps between the new stands remain at least 16 m.

`main_straight_stands.gd` reuses the mile oval's mesh builder and crowd atlas
without changing the oval. Crowd bays repeat across the extra length. Each
ordinary stand has five coloured flags; the finish stand has seven. Their
cloth uses the existing wind shader and remains outside static batching, while
the seating and poles can be batched. All 32 flags were verified in the running
scene, including visible animation between captured frames. Nearby buildings
and palms are cleared from the stand footprints.

The six footprints, road clearance, seven-metre seating height and finish-line
alignment were checked. Driving geometry, AI and session files are unchanged.
Previews: `tmp/surfers_main_straight_view.png` and
`tmp/surfers_finish_stand_view.png`. Previous package:
`tmp/surfers_before_main_stands/`.

## Rebuild and validate

```powershell
python tools/build_surfers_paradise.py 'PATH_TO_SURFERS_FOLDER'
python tools/build_surfers_paradise.py 'PATH_TO_SURFERS_FOLDER' --geometry-only
python tools/validate_surfers_paradise.py
godot --headless --path . --script tools/validate_surfers_player.gd
godot --headless --path . --script tools/validate_surfers_corridor.gd
godot --headless --path . --fixed-fps 60 --script tools/validate_surfers_landscape.gd
godot --headless --path . --fixed-fps 60 --script tools/validate_surfers_paradise.gd
godot --headless --path . --fixed-fps 60 --script tools/validate_surfers_paradise.gd -- --race
godot --headless --path . --fixed-fps 60 --script tools/validate_surfers_paradise.gd -- --race --field
godot --path . --script tools/capture_surfers_paradise.gd
```

The runtime validator uses the production 60 Hz physics clock. Increasing
physics frequency and time scale together would change the effective frequency
of frame-count-based AI planning, invalidating the road-course steering test.
Captures are written under `tmp/`.

The source folder must contain `Surfers.dat` and all four LP files. The builder
also accepts the original `AUSTRAL.DAT` folder to reproduce the stock layout.
It validates LP coverage against the matching TRK before writing output.
The pre-update package and builder are saved locally in
`tmp/surfers_stock_before_custom_2026_10_05/`. A visual comparison is saved in
`tmp/surfers_source_comparison.png` (native scale, independently centred bounds).

For the custom-source build, geometry/provenance, menu selection, player pit
spawn, all 26 paved stalls, road aero baseline and return-to-pits pass. The
corridor probe locates the strongest left/right bends in each current corner
region and checks 48 positions on the two passing paths and main racing line,
plus eight alongside-protection cases. Projection error is zero.

The two-car 660-second rolling-start test completed three timed laps per car,
with best laps of 130.03 and 129.90 s, no wall/car contacts during the race
check and a 1.22 m maximum target-line error. Its subsequent refuelling and
rejoin check also passed. The builder reproduces the old stock geometry and
new custom geometry deterministically; the source-file hashes were verified.

This update changes the Surfers package and its import/validation tools. It
does not change shared AI code, oval data, player physics or wheel controls.

The optional full-field probe is deliberately stricter than basic playability:
it flags target-line errors over 3 m. Close traffic in the narrow chicanes can
still exceed that tolerance while cars make room for one another. Dense-pack
road-course racecraft remains experimental; use the two-car roster or Private
Testing for the cleanest initial handling comparison with the ovals.
On the previous stock-source build, the 20-AI rolling-start run completed two
timed laps per car with no contacts but failed tracking tolerance at 6.81 m.
Those historical results are not validation of the new source geometry.

The custom-source 20-AI green-start probe (`--race --field --green`) ran for
420 simulated seconds. Every AI completed two or three timed laps, and there
were no wall/car contacts. It **failed** the strict 3 m tracking tolerance with
a 5.38 m peak in close traffic. Full-field formation was not rerun; formation
and pit service were checked in the two-car run. Dense-pack tracking remains
a known limitation, not a claimed pass or a reason to change oval racecraft.

After the first-chicane photo pass, terrain probes verified both grass islands'
collision and reduced grip, the kerb crowns and both relocated walls. A player
car crossed the physical bevel onto grass without a wall contact. The two-car
practice/refuelling/rejoin test passed with two timed laps each, zero wall/car
contacts during circulation and 1.05 m peak line error. All AI JSON files and
the session configuration are byte-identical to their pre-landscape versions.
