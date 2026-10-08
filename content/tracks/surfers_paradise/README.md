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
  ranges from 13.6 to 15.04 m. These are not surveyed road edges.
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

## Rebuild and validate

```powershell
python tools/build_surfers_paradise.py 'PATH_TO_SURFERS_FOLDER'
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
