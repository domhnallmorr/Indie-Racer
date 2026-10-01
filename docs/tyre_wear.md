# Race tyre wear

Races use one tyre-condition value per car, starting at 100%. Wear is linear in
distance travelled on track while the race is running, including caution laps.
Formation, pit-lane travel, stationary service, practice and qualifying do not
consume tyres. Cautions use the same wear per metre and therefore less per second.

Initial tuning lives in `game/vehicle/player_state.gd`:

- Player: one percentage point per 1,609.344 metres, or 100 nominal mile laps
  from fresh to fully worn. Fuel capacity does not change tyre life.
- AI: a fixed 0.85–1.15 wear multiplier sampled from each driver's race variation
  seed. A separate random stream preserves fuel and failure draws. The multiplier
  persists through pit stops; repeating the same race seed repeats the setups.
- Player and bicycle AI: grip falls linearly from 1.00 to 0.92. The bicycle AI
  planner also accounts for the reduced grip.
- Reference-profile AI: target lap time gains up to 2.0 seconds, separately from
  the existing fuel-weight penalty. These are provisional gameplay values, not a
  measured equivalence to the player's grip loss.

Both player and AI get fresh tyres when their existing 10–13 second fuel service
completes. There is no additional service time. F3's fuel page shows tyre condition.
At zero condition the penalty stays capped; there are no punctures or retirements.
AI pit decisions remain fuel-driven. Compounds, temperature, individual wheels,
driving-style wear and tyre-driven pit strategy are future extensions.

Validation: `--headless --path . --script res://tools/validate_tyre_wear.gd`.
