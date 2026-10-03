# 2001 IRL pace calibration

The season roster uses the [Phoenix 2001 qualifying classification](https://en.wikipedia.org/wiki/2001_Pennzoil_Copper_World_Indy_200#Qualifying_classification) to distinguish AI pace. Qualifying lap times provide a single-event baseline, not a season-long driver assessment.

Sam Hornish was the quickest driver represented in the original sixteen-driver roster (20.3619 seconds at Phoenix). His existing 21.2-second game benchmark is retained. Each other entry's `icr2_lap_s` is calculated as:

`21.2 * Phoenix qualifying seconds / 20.3619`

This preserves percentage gaps and originally gave targets from 21.2000 seconds (Hornish) to 22.6595 seconds (Hattori). Greg Ray, the actual polesitter, is not currently in the roster. Donnie Beechler is absent from that qualifying classification, so his target uses teammate Eliseo Salazar's time as an explicitly recorded estimate.

The manifest records each driver's source time and qualifying position, plus the calibration formula and source URL. `tools/tune_irl_2001_pace.py` reproduces these values. Entry order, starting grid, liveries and generic driver ratings are unchanged.

These values feed the ICR2 controller's pace scaling; they are not guaranteed measured lap times. Straight-line speed limits, fuel, traffic and line tracking affect actual laps. The validation script checks that the loaded controllers generate speeds in qualifying order, with Beechler matching Salazar. It does not measure a full qualifying session.

Jaques Lazier was subsequently added with the supplied #2 Team Menard livery. He is absent from the Phoenix classification, so Greg Ray’s #2 Team Menard pole time (20.2631 seconds) supplies a same-team-car estimate: 21.0971 seconds. The manifest marks this as a proxy, with no claimed qualifying time or position for Jaques. Existing drivers retain their targets.

Roster correction: Greg Ray now owns the #2 Team Menard entry and its actual Phoenix pole reference. Jaques uses the supplied #99 Sam Schmidt livery. His prior 21.0971-second pace is retained provisionally; it is no longer described as a same-team-car comparison. No other driver pace changed.

Sarah Fisher (#15 Walker Racing / Kroger) is the nineteenth entry. Her Phoenix qualifying time of 21.3209 seconds (21st in the linked classification) gives a 22.198473-second target using the same formula, between Daré and Unser. She is appended to the existing game grid; the grid is not reordered to match Phoenix qualifying.

Didier André (#32 Galles Racing / PlayStation 2) is the twentieth entry. His Phoenix qualifying time of 22.8211 seconds (27th in the linked classification) gives a 23.760421-second target with the existing formula. He is appended to the game grid without changing the other entries.
