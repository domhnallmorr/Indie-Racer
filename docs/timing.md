# Practice lap timing

Press **9** to show/hide the timing panel in the top-right corner. It starts hidden
and works in cockpit and exterior views. Rows show position, driver, best lap,
last lap and completed timed laps. The player row is highlighted.

Practice positions are ordered by fastest best lap, with untimed drivers below
timed drivers. Equal best times retain registration order. These are practice
standings, not physical race positions. Times display minutes:seconds.milliseconds.

The first forward crossing of the painted start/finish line starts a timed lap;
the out-lap is not counted. A completed lap requires forward passage through the
three intermediate gates in order, then start/finish again. Pit-lane travel beside
the finish line cannot trigger it. Crossing backwards cancels the current lap.
R resets the player's active lap while preserving best/last times and completed
laps; the next finish-line crossing begins a fresh attempt.

`content/tracks/mile_oval/ai/timing_gates.json` defines the gates in track-local
metric coordinates. Start/finish is X=61.79594 m on the front straight, matching
the painted stripe. The other gates sit at the middle of each end and backstraight.
Crossing times are interpolated within a physics tick. This is ordered-checkpoint
validation, not comprehensive track-cut or all-wheels track-limit enforcement.

`game/race/lap_timing.gd` owns the results for all three cars; AI route-loop counters
are only driving diagnostics and are not used for official lap timing. Results
freeze when the practice session ends and are cleared by restarting the scene.
The cockpit's separate LAP/TIME placeholders are unchanged; the timing panel is
the live results display. No results persistence or race classification yet.

`tools/validate_timing.gd` tests interpolation, best laps, out-lap handling,
reverse/shortcuts/reset, sorting, key toggling and live AI timed laps. A graphical
run also writes `builds/timing_panel.png` for layout review.
