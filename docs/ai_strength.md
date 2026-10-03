# AI strength

Race Weekend Setup includes an integer slider from 90 to 120, defaulting to
100 (the existing calibration). The selected value appears in the weekend
summary and is retained through practice, qualifying, races and returning to
the menu within the running game. It is not saved across application restarts.

Each point changes AI target speed by 0.25%: 90 gives 97.5% of baseline speed,
110 gives 102.5%, and 120 gives 105%. This is a difficulty scale, not a literal
percentage of car speed. Actual lap times also depend on traffic and car state.

The ICR2 controller applies this factor to the combined driver, fuel and tyre
lap target. Both the reference-speed lookup and tow braking preview use it;
the guarded straight-line rating spread cannot clamp away difficulty. Pit-lane
cruise, departure and formation targets retain their existing limits, while the
final pit-exit acceleration blends into the selected racing pace. Player physics
are unchanged. The legacy bicycle driver scales racing corner-speed targets
inside its braking preview; its physical grip and engine limits still apply.

AI diagnostic metadata includes `roster.ai_strength`. Selection values are
clamped at session setup and again by the driver.

Validation:

- `tools/validate_race_setup.gd`: default, displayed value, summary, selection
  storage, return-to-weekend restoration and viewport fit.
- `tools/validate_ai_strength.gd` (headless, `--fixed-fps 60`): seeded two-car
  Texas clean-air runs at 90, 100 and 120, actual timed laps and road bounds.
  Mean laps after the initial lap: 23.227 s, 22.646 s and 21.568 s respectively.
  Maximum road-centre offset stayed below 6.99 m at all three settings.
- `tools/validate_ai_fuel.gd`: existing default-strength fuel regression passes.
- The Texas full-field racecraft fixture also passed with strength set to 120:
  formation plus 60 seconds of green running, three completed passes, zero
  contacts and zero road-boundary violations (maximum offset 8.136 m).

The setup menu was also rendered and checked at 1280 × 720.
