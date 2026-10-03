# Practice and race tyre wear

Practice and races use one tyre-condition value per car, starting at 100%. Wear is linear in
distance travelled on track while the session is running, including caution laps.
Formation, pit-lane travel, stationary service and qualifying do not
consume tyres. Cautions use the same wear per metre and therefore less per second.

Initial tuning lives in `game/vehicle/player_state.gd`:

- Baseline: one percentage point per 1,609.344 metres, or 100 nominal mile laps
  from fresh to fully worn. Fuel capacity does not change tyre life.
- Every car, including the player, receives a seeded wear multiplier in practice
  and races. A separate random stream preserves fuel and failure draws. The
  multiplier persists through pit stops; the same session seed and car identity
  repeat the setups, independently of grid position.
- Player and bicycle AI: grip falls linearly from 1.00 to 0.92. The bicycle AI
  planner also accounts for the reduced grip.
- Reference-profile AI: target lap time gains up to 2.0 seconds, separately from
  the existing fuel-weight penalty. These are provisional gameplay values, not a
  measured equivalence to the player's grip loss.

Both player and AI get fresh tyres when their existing 10–13 second fuel service
completes. There is no additional service time. F4's tyre page shows condition as a percentage and a decreasing bar (green above 50%, amber above 25%, red at 25% or below). Practice pit-box arrivals restore fresh tyres for the next stint.
At zero condition the penalty stays capped; there are no punctures or retirements.
AI pit decisions remain fuel-driven. Compounds, temperature, individual wheels,
driving-style wear and tyre-driven pit strategy are future extensions.

Variation settings live in `content/vehicles/open_wheel/physics/tyre_wear.cfg`:

```ini
[variation]
enabled=true
min_multiplier=0.85
max_multiplier=1.15
```

Lower multipliers preserve tyres longer; 0.85 means 15% slower wear and 1.15
means 15% faster wear. Set `enabled=false` for baseline 1.0 wear on every car;
this disables variation, not wear itself. Bounds must be finite and positive,
with minimum no greater than maximum. Equal bounds give a fixed multiplier.
Missing or invalid configuration warns and falls back to baseline wear.
Settings are loaded at session start; start a new session after editing.
Fresh-tyre grip and maximum worn-tyre penalties are unchanged.

Validation: `--headless --path . --script res://tools/validate_tyre_wear.gd`.
