# Rear stagger experiment

> Historical investigation: this handling variant and its diagnostic scripts were
> retired on 10 October 2026. The rear differential is now the only player model.

In **F10 → Controls → Player Handling**, select **Rear stagger experiment**
from the dropdown. It enables free front wheels and starts at +5 mm; adjust the
**Rear stagger experiment (mm)** field below. Positive means the right rear tyre has a larger rolling
circumference than the left rear. The range is −50 to +50 mm in 5 mm steps.
Selecting **Free front wheels (default)** restores zero stagger and the existing
handling. Start comparisons
with 0, +5 and −5 mm at the same fuel, wings, gearing, tyres and assists.

This is a session-only experiment. Resetting to the pits retains it; starting a
new session clears it. Original handling and the shared-front experiment ignore
the setting, and their stagger control is disabled. F11 records the setting,
whether it is active, and the individual wheel forces and slips.

## What the ICR2 executable establishes

The inspected `INDYCAR.EXE` SHA256 is
`83ccee7341b31ce2fdebfb453dfaaf443c1e80687693e6ba4b71a71dd8256267`.
It contains an embedded DOS/4GW LE application. Its application MZ starts at
file offset `0x26654`, LE header at `0x28C9C`, code pages at `0x67454`, and
initialized data at `0xF1454`. The LE object's code base is `0x10000`.

The Stagger menu descriptor references More/Less callbacks at code addresses
`0x6949C`/`0x694B4`. These change a signed internal value by 100. Setter
`0x13A74` clamps it to −1000…+1000 and writes words at data-object offsets
`0x8848`/`0x884A`. Running code at `0x16D14` uses the signed word to form a
paired `(base ± adjustment)/2` split, with a 16-bit fixed-point shift. The two
outputs pass through limits into the tyre-combination call at `0x172CD`.

This establishes a path from setup to tyre arithmetic. It does **not** establish
the physical units, exact wheel identity, circumference conversion, differential
construction or original force law. The prototype below is an independent
physical hypothesis, not a conversion of those internal values.

[analyse_icr2_stagger.py](../tools/analyse_icr2_stagger.py) reproduces the read-only
trace and rejects other executable hashes. It requires Capstone; the review's
temporary installation is supported. Run it with the original EXE path to save
`tmp/icr2_analysis/stagger_binary_trace.json`. The original executable is never
executed or changed.

## Model

With signed circumference difference `d` in metres and authored rear radius `R`:

```text
R_left  = R - d/(2*TAU)
R_right = R + d/(2*TAU)
kappa_i = (rear_omega*R_i - wheel_contact_speed_i) / slip_reference_i
rear_reaction_torque = Fx_left*R_left + Fx_right*R_right
rear_track_yaw_moment = rear_track/2 * (Fx_right - Fx_left)
```

Both tyres retain one rear rotational speed. Their contact speeds already include
yaw and track width. Mean rolling radius, nominal gearing, stiffness, grip,
load transfer and brake bias remain unchanged. The shared rear shaft responds
to radius-weighted tyre reaction torque; equal brake force per side gives the
same total brake torque because the mean radius is preserved. Active ABS uses
the stricter rear lock-up bound, and TC uses the stricter wheelspin bound.

Telemetry's per-wheel forces are in tyre coordinates; rear tyre coordinates
match the body frame. Each rear yaw contribution includes both `−b*Fy` and its
signed track-width `Fx` moment. Values describe the last force evaluation of the
tick, before the following state update/assist intervention; they are not tick
averages. Axle slip fields remain centre-of-axle summaries. The nonzero variant
identifies itself as `wheel_contacts_rear_stagger_v1`; metadata explicitly marks
the ICR2 units as unverified.

This stagger mode has no differential solver, pressure/temperature effect, suspension travel
or tyre deformation. This setting must not be treated as a general slide fix.

## Controlled comparison, 9 October 2026

[compare_rear_stagger.gd](../tools/compare_rear_stagger.gd) fixes the recorded
`surfers_downshift.cfg` parameters and uses fresh synthetic feedback at 60 Hz.
It compares 0 and ±25 mm, mirrored steering/stagger, constant-speed flat and
24-degree banked turns, and power/brake/reversal corrections delayed by
0–0.3 seconds. These are synthetic scenarios, not driven laps or driver models.

For a left turn, steady yaw rate in degrees/second:

| Circumference difference | Flat, 25 m/s | Banked, 60 m/s |
| --- | ---: | ---: |
| −25 mm | 12.068 | 4.711 |
| 0 mm | 13.429 | 7.340 |
| +25 mm | 14.801 | 10.060 |

In the power-slide case with a 0.2-second correction delay, peak sideslip was
30.633° at zero, 38.007° at +25 mm and 33.175° at −25 mm. All recovered while
still moving forward, but neither stagger improves this comparison. At a
0.3-second delay all three spin and reverse: the late recovery remains a limit.
Brake turn-in stays below the 3° trigger; the harness reports a stable turn-in
rather than requiring an invented slide. The heavy-braking reversal recovers
for all tested delays/settings.

The existing axle recovery harness originally failed its assumption that the
free-front brake case must provoke breakaway. Its pre-change measurements are
retained; the new harness distinguishes stable turn-in, actual recovery and
failed recovery. Passing mechanics checks is separate from acceptable handling.

The final before/after interleaved model-only CPU benchmark measured medians
of 0.547 ms before, 0.587 ms at zero and 0.588 ms at +25 mm. Added diagnostics
cost about 0.04 ms per tick in this capture; these are not rendered frame timings.
See `tmp/icr2_analysis/stagger_cpu_before_after.json` for the local capture.

## Validation and next driving run

[validate_rear_stagger.gd](../tools/validate_rear_stagger.gd) checks pre-change
zero-stagger recovery traces, circumference units, rejected inputs, mirrored
forward/reverse behaviour, shaft torque/yaw, ABS/TC bounds, inactive modes,
airborne/reset behaviour, flat/banked convergence, live controls and telemetry.
Preference tests need an isolated `APPDATA` directory. Existing free-front,
handling-selection and telemetry validators also pass.

Keep the default at zero. Next, compare fresh driving at 0 and ±5 mm: steady
oval balance, Surfers brake entry and power exit, and the speed/countersteer
needed to catch a slide. Record F11 telemetry and use the individual rear force
and yaw fields to separate a balance change from improved recovery. Human
driving and exact ICR2 unit calibration remain outstanding.
