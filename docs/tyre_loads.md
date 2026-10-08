# Tyre loads and roll balance

The player now evaluates left/right tyre loads and forces while retaining the
existing front/rear axle slip and wheel-speed model. Steering remains independent
of grip, wings and yaw. This is a load-resolution step, not a full suspension or
four independent wheel-speed simulation.

## Driving and setup

Press **F5** for the live **Tyre Loads** panel. FL/FR/RL/RR mean front left/front
right/rear left/rear right. Loads are in newtons; grip usage is delivered combined
force divided by that tyre's current load-sensitive peak. **SLIDING** means the
tyre is beyond its force peak, even if the usage number has fallen below 100%.
**UNLOADED** identifies a wheel with less than 1 N of normal load. The display
does not pause or capture driving controls; F4 retains tyre condition.

While parked in a practice, qualifying or Private Testing pit stall, open the pit
monitor and select **Edit Car Setup → Roll Balance**. The default is 50% front
and 50% rear. The front adjustment spans 35–65%; the rear is the remainder.
Apply saves the setting per track in `user://mechanical_setups.cfg`. Moving-car
and race-session changes are rejected. This does not change static weight split,
wing settings, or steering sensitivity.

More front roll stiffness transfers more cornering load across the front axle,
usually increasing understeer; moving the share rearward encourages rotation.
Begin with the existing wing setup and 50%, then make small changes to this one
setting. Compare at the same fuel load, speed and tyre condition.

## Model boundaries

The front/rear loads already include fuel, downforce, banking support and
longitudinal transfer. Lateral contact force creates a roll moment through the
configured CG height. A 0.12-second response filters this moment, which is split
between axles by roll stiffness and converted into load transfer using track
width. This avoids counting gravity on a bank as additional tyre force. Positive
leftward tyre force moves load to the right tyres. Axle totals are conserved and
wheel loads cannot become negative.

Each side evaluates half of the axle-reference tyre curve at twice its individual
load. This preserves axle stiffness calibration. Peak force uses a mild 0.98 load
exponent; cornering stiffness retains its separate 0.85 exponent. Unequal loads
therefore reduce combined capacity. At equal loads and peak exponent 1, the
summed curve exactly matches the old axle curve.

Parameters are provisional. Both wheels on an axle share slip and angular speed;
there is no differential, per-wheel contact velocity, suspension travel, camber,
roll-centre geometry, or separate surface sampling. Wheel-lift clipping does not
model rollover or redistribute excess roll moment. The existing yaw-based bank
support approximation remains. Tyre condition is still one value for the car.

## Verification and baseline

- [Saved baseline](../tools/fixtures/texas_before_four_tyre_loads.json): old
  parameters, model hash, Texas replay peaks and the latest driven 6/3 summary.
- [Load tests](../tools/validate_tyre_loads.gd): conservation, signs, wheel lift,
  force limits, load sensitivity, roll balance, bank gravity and reset.
- [Setup/display tests](../tools/validate_roll_setup.gd): pit controls, per-track
  persistence, invalid data, restrictions, unchanged steering and F5 diagnostics.
- [Lift tests](../tools/validate_lift_off.gd) retain their previous bounds and
  compare 60/120 Hz; steering, oversteer recovery and player-adapter tests remain.

Telemetry adds load, peak capacity, usage and normalized demand for each corner,
plus current front roll stiffness, filtered lateral contact acceleration and
front/rear transferred load. Demand 1 is the force peak; values above 1 are
post-peak. See [equations](player_physics_model.md) for details.
