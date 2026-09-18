# Team transporters

26 parked race-team trucks: 20 at the T3/T4 (negative X) end of the paved paddock and six at the T1/T2 (positive X) end. Two opposing rows put the cabs toward an approximately 11 m central aisle. Trucks remain clear of the service lane, cross access, inner wall and media-centre walkway.

One procedural mesh is shared by all 26 instances in a MultiMesh. The conventional tractor includes a sleeper cab, bonnet, split windscreen, mirrors, grille, exhaust stacks, lamps and five axles including the trailer tandem. The 13.6 x 2.6 m enclosed trailer has a white roof, lower stripe, storage lockers, landing legs, rear loading doors and locking bars. Overall length is approximately 20.6 m; trailer height is 4.15 m.

Thirteen sponsor-inspired colour schemes are defined in `LIVERIES`, with simple readable sponsor names on each trailer side; these are artistic liveries, not exact historical replicas or linked to the current driver roster. Instance custom data supplies the paint colour, while white instance colours preserve the shared mesh's fixed trim colours. Labels are separate Label3D nodes. All geometry is generated locally; no downloaded assets are used.

These are static scenery without collisions, matching the existing parked RVs. Placement is deterministic and editable in `_ready()`. The model is generated in `_make_truck()`.

Run Godot with `--path . --script tools/capture_transporters.gd` to check instance count, paved-lot bounds, building clearance and truck overlap, and render overview/detail/east screenshots into `builds/`.
