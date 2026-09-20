# 2001 IRL pace calibration

The season roster uses the [Phoenix 2001 qualifying classification](https://en.wikipedia.org/wiki/2001_Pennzoil_Copper_World_Indy_200#Qualifying_classification) to distinguish AI pace. Qualifying lap times provide a single-event baseline, not a season-long driver assessment.

Sam Hornish is the quickest driver represented in this roster (20.3619 seconds at Phoenix). His existing 21.2-second game benchmark is retained. Each other entry's `icr2_lap_s` is calculated as:

`21.2 * Phoenix qualifying seconds / 20.3619`

This preserves percentage gaps and gives targets from 21.2000 seconds (Hornish) to 22.6595 seconds (Hattori). Greg Ray, the actual polesitter, is not currently in the roster. Donnie Beechler is absent from that qualifying classification, so his target uses teammate Eliseo Salazar's time as an explicitly recorded estimate.

The manifest records each driver's source time and qualifying position, plus the calibration formula and source URL. `tools/tune_irl_2001_pace.py` reproduces these values. Entry order, starting grid, liveries and generic driver ratings are unchanged.

These values feed the ICR2 controller's pace scaling; they are not guaranteed measured lap times. Straight-line speed limits, fuel, traffic and line tracking affect actual laps. The validation script checks that the loaded controllers generate speeds in qualifying order, with Beechler matching Salazar. It does not measure a full qualifying session.
