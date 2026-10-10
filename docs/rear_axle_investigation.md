# Rear axle and slide recovery investigation

> Historical investigation: this handling variant and its diagnostic scripts were
> retired on 10 October 2026. The rear differential is now the only player model.

Investigated 2026-10-09. Recommendation: develop explicit rear differential
behaviour next, with separate rear wheel speeds and independently tunable drive
and coast locking. Keep the current handling available for comparison. The tests
show that rear coupling strongly affects cornering and breakaway; they do not
identify a universally better setting or establish the original ICR2 mechanism.

No gameplay equations, F10 options, saved preferences or defaults were changed
for this investigation. All prototypes ran in offline diagnostic scripts.
The subsequent [playable rear differential experiment](rear_differential.md)
adds a bounded friction-clutch option while retaining the existing default.
The offline viscous adapter now reuses its independent-wheel integration and
replaces only the coupling law; the reported investigation results above predate
that implementation.

## What the current model does

The free-front handling mode still uses one `rear_omega` for both rear tyres.
In a turn their ground speeds differ (`u ± yaw_rate * rear_track / 2`), so equal
tyre radii and equal rotational speed produce different longitudinal slips.
This is a locked rear shaft in rotational terms. It creates both longitudinal
scrub and a track-width yaw moment; it is not simply a different tyre-grip value.

In a neutral, constant-speed 25 m/s flat turn with 2 degrees steering and zero
stagger, the current rear tyre forces are approximately +428 N left and -409 N
right. Their track-width contribution is -669 Nm, resisting the left turn.
The independent rear prototype has approximately +9 N and +10 N instead, with
only +1 Nm track-width contribution. The small common forward force persists
because the test externally maintains forward speed. Total body yaw also depends
on front forces and the rear lateral forces.

| Rear model | Flat-turn yaw rate (deg/s) | Rear track-width yaw moment (Nm) |
| --- | ---: | ---: |
| Current shared shaft | 13.429 | -669.1 |
| Independent, equal drive torque | 15.458 | +1.1 |
| Viscous coupling 10 Nm s/rad | 15.288 | -53.8 |
| Viscous coupling 40 Nm s/rad | 14.914 | -176.2 |
| Viscous coupling 150 Nm s/rad | 14.269 | -388.8 |

The same mechanism appears in the 60 m/s, 24-degree bank test. Independent rear
speeds increase yaw rate from 7.340 to 8.220 deg/s. This concerns both road and
oval handling, unlike deliberate asymmetric tyre stagger.

## Isolated hypotheses

`tools/rear_axle_experiment.gd` builds a temporary script from the production
model with checked replacement anchors. It splits the authored rear axle inertia
equally between two wheels, applies half the drive torque to each, and uses each
wheel's own tyre reaction and brake torque. The engine and clutch couple to the
mean rear speed. Stagger stays zero in all comparisons.

Zero coupling represents an ideal equal-torque open differential. Positive
coupling adds equal and opposite viscous torque proportional to wheel-speed
difference. Its damping step preserves mean rotational speed and removes kinetic
energy. These are diagnostic hypotheses, not a calibrated clutch limited-slip
differential. Mechanical references: [ideal differential](https://www.mathworks.com/help/sdl/ref/differential.html),
[viscous rotational damper](https://www.mathworks.com/help/simscape/ref/rotationaldamper.html),
[clutch limited-slip differential](https://www.mathworks.com/help/sdl/ref/limitedslipdifferential.html).

The previous EXE analysis verified a signed stagger setting reaching a paired
tyre-force calculation. It did not verify individual wheel-speed state,
differential torque allocation, drive/coast locking or physical stagger units.
These experiments therefore do not claim to reproduce ICR2's rear differential.

## Breakaway and recovery

Fresh synthetic driving tests use identical initial conditions, tyre curve,
60 Hz control cadence and a sideslip/yaw feedback controller. Correction starts
after sideslip crosses 3 degrees plus the selected delay. Outcomes distinguish
an untriggered stable turn from an actual recovered slide.

| Rear model | Power test: peak sideslip, 0.2 s correction delay | Outcome | Brake test: peak sideslip, 0.2 s delay |
| --- | ---: | --- | ---: |
| Shared shaft | 30.63 deg | Recovered | 1.95 deg; no correction triggered |
| Independent | 2.32 deg | No correction triggered | 5.31 deg; recovered |
| Coupling 10 | 12.01 deg | Recovered | 5.13 deg; recovered |
| Coupling 40 | 36.17 deg | Failed; ended below 10 m/s | 4.25 deg; recovered |
| Coupling 150 | 30.08 deg | Recovered | 2.39 deg; no correction triggered |

At 0.3 s power-correction delay the shared shaft reverses forward motion and
fails recovery. Coupling 10 recovers after a 45-degree peak. Independent rear
rotation never triggers the 3-degree correction threshold in this particular
power test. That is different breakaway behaviour, not proof of superior recovery.
The response is not monotonic with coupling strength.

To separate breakaway from recovery, another test imposes identical 10-, 20-
and 30-degree body slides at 30 m/s and -0.35 rad/s yaw, with immediate or delayed
correction. All 30 cases recover with this controller. Independent rotation does
not consistently recover faster. For the imposed 20-degree slide with immediate
correction, the shared shaft settles in about 1.52 s; independent rotation takes
3.20 s and reaches 33.66 degrees. Coupling 10 takes 3.30 s. A different controller
could change these results; this is not a human driving assessment.

## Recorded-input checks

Replayed nine existing collision-free Surfers windows using shared, independent
and coupling-10 rear models, with free front rotation throughout. Inputs remain
open loop: the driver cannot respond to the changed car. Initial rear speeds
are seeded from the recorded common shaft, and separate front speeds are seeded
from the reconstructed front mean. The fixture does not record complete shift
timer or individual wheel state. These are sensitivity checks, not faithful
reproductions of driving laps.

| Window | Shared peak (deg) | Independent peak (deg) | Coupling 10 peak (deg) |
| --- | ---: | ---: | ---: |
| Direction change | 89.91 | 4.53 | 89.97 |
| Fast entry | 6.62 | 42.63 | 34.19 |
| Heavy trail braking | 4.95 | 9.01 | 9.02 |
| Clean fast | 49.21 | 3.68 | 4.25 |

Other windows also show mixed changes. The largest entire-trace sideslip error
after halving the integration step is 0.465 degrees, in the coupling-10 direction
change. Steady-turn sideslip errors stay below 0.001 degrees. The controlled
power test at 0.2 s delay changes peak sideslip by less than 0.043 degrees under
refinement, and all five outcomes agree. An imposed 20-degree slide with coupling
150 is more sensitive: peak changes 0.304 degrees and settlement 0.10 s, while
the recovery outcome agrees.

The two most recent user logs contain moving laps at +5 mm stagger, with no
usable moving zero-stagger baseline. They contain samples of opposing rear
longitudinal force, but this alone does not establish the cause of a spin.
Their largest instantaneous collision-filtered sideslip samples may follow
earlier impacts; they were not used as collision-free recovery evidence.

## Verification and reproducibility

Headless Godot 4.7.2 completed both investigation scripts and the mechanics
validator. Checks cover mean-speed conservation, exact unloaded viscous decay,
positive energy dissipation, torque direction, straight neutral braking in
forward/reverse, mirrored controlled turns, separate-wheel ABS/TC bounds,
reset and selected integration refinement. No failures were recorded.

Run with a separate `APPDATA` directory, using the existing Godot console binary:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'tmp\icr2_analysis\rear_axle_userdata'
$godot = 'C:\Users\domhn\Documents\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --script tools/investigate_rear_axle.gd
& $godot --headless --path . --script tools/investigate_rear_axle_recovery.gd
& $godot --headless --path . --script tools/validate_rear_axle_experiment.gd
```

Full traces: `tmp/icr2_analysis/rear_axle_investigation.json` (70 comparisons)
and `tmp/icr2_analysis/rear_axle_recovery.json` (30 imposed slides and 27 replays).
The first file identifies the production source SHA-256 used for the comparison.

## Next development step

Implement separate rear rotational states with explicit differential torque
allocation, retaining the current locked mode as an A/B baseline. Add bounded
preload and separate drive/coast locking rather than choosing one fixed viscous
coefficient from these tests. Preserve axle inertia, track-width moments and
individual brake reactions, and log rear wheel speeds and coupling torque.

Then drive zero-stagger road-course laps comparing corner entry, lift-off,
trail braking and power exit with the same setup. Verify wheelspin, acceleration
and recovery together. Independent wheels improve some power-breakaway cases
but remove a stabilising coast yaw moment; drive/coast calibration is essential.
Investigate tyre transient response after axle behaviour is explicit. The
present results do not justify changing the tyre's sliding-grip curve or
promoting stagger as a general road-course handling improvement.
