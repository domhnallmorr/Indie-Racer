# Infield RV camping

Five procedural low-poly models: motorcoach, cab-over motorhome, rounded silver travel trailer, fifth-wheel trailer, and compact camper van. Each includes wheels, windows, trim, lights, rooftop equipment and a rear ladder; the larger models include striped awnings, folding chairs and a cooler.

Thirty deterministic placements form three groups of ten inside Turn 2, along the back straight and inside Turn 3. The grass strip between the backstraight road course and retaining wall requires a single row. Corner groups follow the curved wall. Small seeded angle and position variations break up the parking lines. Geometry stays inside the inner wall with at least two metres of clearance; service road crossings stay open.

Five MultiMesh instances share the model geometry, each drawing six RVs. Visual scenery only, with no collision or race logic changes. `tools/capture_rvs.gd` checks model counts and every transformed vertex against the inner wall, and produces overview, backstraight and model-selection screenshots in `builds`.
