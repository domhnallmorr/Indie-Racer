# Slipstream

Player and bicycle-physics AI use the same tow calculation. The follower's drag
is reduced by up to 9%; engine power and calculated airspeed are unchanged.
The human player's downforce also falls in dirty air, as described below.
Extra speed therefore depends on power, gearing, distance in the tow
and the existing corner/traffic constraints. There is no fixed speed bonus.

Initial gameplay tuning lives in `game/vehicle/slipstream.gd`:

- The wake extends 75 m behind a car, measured between vehicle origins. Full
  longitudinal strength is available at 7–10 m, fading smoothly to zero at 75 m.
  Overlapping cars (4.5 m or closer) do not generate a tow for each other.
- Half-width grows from 1.6 m by 0.015 m per metre behind the leader. Strength
  fades laterally from the centreline to the edge. Heading alignment and vertical
  separation also fade the effect, excluding oncoming cars and separate levels.
- The slower car's forward speed gates the wake: zero below 20 m/s, full above
  45 m/s. Only the strongest wake applies; a pack never stacks reductions.
- Exponential build/release time constants are 0.35/0.25 seconds. Leaving the
  wake restores drag without removing the speed already gained. Reset clears it.
- Pit-lane cars, ghosted cars, retired cars, disabled tow participants and cars
  on another track are excluded. `slipstream_enabled` can disable a car's
  participation for clean-air measurements.

The bicycle AI's existing planner already permits unrestricted speed on clear straights
and extends braking lookahead with actual speed. Its corner grip, following,
pit and caution limits remain in force; no tow bonus is added to these limits.
Clean-air downforce still grows with actual airspeed. There is no leader drag benefit.

The human player also receives a dirty-air penalty using the same wake geometry,
speed gates, eligibility and strongest-wake cap. At full strength, front downforce
falls by 20% and rear downforce by 10%, shifting aero balance rearward to encourage
understeer. These are initial gameplay values, set independently of drag reduction
by `MAX_FRONT_DOWNFORCE_LOSS` and `MAX_REAR_DOWNFORCE_LOSS` in `slipstream.gd`.
Unlike tow, dirty air remains at full longitudinal strength at positive gaps below
10 m, including close contact; it is zero beside or ahead of the leader. It builds
with a 0.35 s time constant and releases over 0.25 s. Reset clears both target and
strength. The reduced axle loads feed tyre forces and the reduced total load feeds
the steering assistance calculation; mechanical grip is unchanged. AI handling
is unchanged. Set the player's `dirty_air_enabled` to false to compare clean-air
handling while retaining tow.

Current ICR2 rosters use reference-speed AI rather than force integration. They
share the wake geometry, eligibility and drag-reduction smoothing. Their tow
speed allowance approximates the power-limited relationship
`speed multiplier = (1 - drag reduction)^(-1/3)`, with a four-second response
to build speed and coast after pulling out. The allowance fades with track
curvature and previews upcoming profile speeds using a braking envelope. It is
applied before traffic, caution, pit and off-line safety limits. This is an
approximation for that controller; it does not change its clean-air profiles.

Key 8 shows tow strength and current drag reduction. F11 player telemetry appends
`slipstream_target`, `slipstream_strength` and `slipstream_drag_reduction` as 0–1
fractions. These are prototype tuning values, not measured IndyCar wake data.
The panel also shows dirty-air strength and front/rear downforce loss. Telemetry
appends `dirty_air_target` and `dirty_air_strength` as 0–1 fractions.

Run `tools/validate_slipstream.gd` headlessly for wake geometry, pack limits,
player/AI participation, drag/downforce, speed gain, release and reset checks.
`tools/validate_slipstream_pack.gd` exercises a seeded 15-car field already on
track for one simulated minute, checking active towing, contacts and boundaries.
Pass `-- --without-tow` for a comparison with the same starting positions.

The reference AI caches track curvature, segment lengths and reference pace
weights when loading the track. Each braking-envelope query computes dynamic
fuel, tyre and lane factors once, and works in squared speeds until its final
result. This preserves the original envelope without repeating geometry and
state queries for every upcoming point on every car's physics tick.
`tools/validate_tow_planner.gd` compares the cached result against direct geometry
on both tracks, including changing fuel, tyres, driver pace and tow strength.
`tools/profile_slipstream.gd` measures the planner and wake queries separately;
`tools/profile_texas_start.gd` replays the Texas/2001 IRL formation and opening
30 seconds with `--headless --fixed-fps 60`. These CPU measurements exclude rendering.
