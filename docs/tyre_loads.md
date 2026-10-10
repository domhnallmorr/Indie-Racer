# Tyre loads and roll balance

The player evaluates left/right tyre loads, contact velocities, forces and
individual wheel speeds. Steering remains independent of grip, wings and yaw.
The [rear differential](rear_differential.md) uses a simplified bounded clutch.
Suspension travel is available in the Indianapolis human-player prototype.
Earlier handling variants have been retired.

At Indianapolis, **Dynamic suspension** uses body reaction forces instead of the
transfer filters described below. With **Heave and wheel travel** enabled,
four road contacts supply the tyre loads directly through spring/damper forces.
Uncheck travel in **Edit Car Setup → Roll Balance** to compare with the accepted
roll/pitch-only stage, or disable dynamic suspension for the original filters.
F5 adds body angles and corner travel. See [travel notes](indy_suspension_travel.txt)
and [earlier Indy test results](indy_suspension_test.txt).

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
load. This preserves axle stiffness calibration. Peak capacity now uses the
proposed ICR2 load-efficiency polynomial on the actual individual load, with
0.469078 native load units per newton and a 1.1 front-pair adjustment. Zero-load
friction is 1.749509, from the baseline compound factor 58200. This conversion
is provisional, matched to the static weight in the Indy recording. Smooth
arithmetic avoids the original integer steps near wheel lift. Cornering stiffness
retains its separate 0.85 exponent, and post-slide force retains its 85% floor.
The curve substantially reduces capacity on heavily loaded outside tyres.
See [the proposed curves](plots/proposed_tyre_load_dropoff.png) and
[binary investigation](icr2_tyre_binary_review.txt) for the calibration basis.

Parameters are provisional. Each wheel has its own contact velocity and
rotational speed. The rear differential couples rear rotational states through
a bounded friction clutch. There is no suspension travel, camber, roll-centre
geometry, or separate
physical surface sampling. Wheel-lift clipping does not
model rollover or redistribute excess roll moment. The existing yaw-based bank
support approximation remains. Tyre condition is still one value for the car.

## Verification and baseline

- [Saved baseline](../tools/fixtures/texas_before_four_tyre_loads.json): old
  parameters, model hash, Texas replay peaks and the latest driven 6/3 summary.
- [Load tests](../tools/validate_tyre_loads.gd): conservation, signs, wheel lift,
  force limits, load sensitivity, roll balance, bank gravity and reset.
- [Setup/display tests](../tools/validate_roll_setup.gd): pit controls, per-track
  persistence, invalid data, restrictions, unchanged steering and F5 diagnostics.
- [Lift tests](../tools/validate_lift_off.gd) compare 60/120 Hz. With this load
  curve, the historical Texas entry/exit/late steering replays exceed their
  old slide bounds. Their peak sideslip is approximately 65/56/18 degrees;
  the previous grip curve gives about 3/8/3 degrees (the old exit case already
  exceeds its bound). Both frame rates agree. These are unchanged-input replays,
  not fresh driving laps; this trial needs track testing before further tuning.
  Tyre loads, oversteer recovery, gearbox, rear differential and player-adapter
  validations pass. The legacy slide bounds have not been relaxed.

Telemetry adds load, peak capacity, usage and normalized demand for each corner,
plus current front roll stiffness, filtered lateral contact acceleration and
front/rear transferred load. Demand 1 is the force peak; values above 1 are
post-peak. See [equations](player_physics_model.md) for details.
The sidecar configuration now records `tyre_load_curve` and its provisional
normalization so recordings can distinguish this trial from the earlier curve.
