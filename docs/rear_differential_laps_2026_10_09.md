# Rear differential: driven Surfers telemetry, 9 October 2026

Source: `practice_2026-10-09T17-33-06_8027.csv` in the normal Godot user telemetry
directory. Parsed all 47,822 rows, covering 797.03 seconds, without malformed
rows. This review changes no gameplay physics, defaults or saved settings.

## Conditions

The player selected `wheel_contacts_rear_differential_v1` at elapsed 2.983 s and
kept it for the remainder. Settings stayed at 30% drive locking, 10% coast locking,
20 Nm preload and zero stagger. The initial free-front mode was stationary, so
there is no driven baseline in this log.

Wings remained 14 degrees front/rear, with master assistance and speed steering
help at 100%, stability and traction control at 0%, and ABS at 100%.

`collision_count` includes ordinary ground contacts and must not be treated as
a wall-impact count. The dedicated wall telemetry is emitted for closing speeds
of at least 1 m/s. Smaller wall scrapes and car contacts are not separately
identified in this CSV; “no logged material wall impact” is therefore more
precise than “collision-free”.

Statistics below use forward speed above 10 m/s, grounded tarmac, no pit limiter
or setup screen, excluding two seconds either side of a logged wall impulse or
position reset and half a second around settings changes. No position resets
were detected. This leaves 749.38 seconds of usable driving. The speed filter
excludes the low-speed tail of the early spin, which is examined separately.

## Laps

Laps were reconstructed from ordered crossings of all four Surfers timing gates.
No lap contains a setup interruption or detected position reset.

| Completed lap | Time | Logged material wall-impact samples | Off-tarmac samples |
| --- | --- | ---: | ---: |
| 1 | 1:34.375 | 0 | 0 |
| 2 | 1:34.427 | 0 | 45 |
| 3 | 1:37.084 | 3 | 0 |
| 4 | 1:41.033 | 3 | 0 |
| 5 | 1:32.719 | 0 | 0 |
| 6 | 1:32.750 | 0 | 0 |
| 7 | **1:32.195** | 0 | 0 |

Impact samples are individual ticks, not counts of independent accidents. The
last three laps are consistent in time, but learning, fuel reduction and driving
changes cannot be separated from handling without an A/B run.

## Rear differential behaviour

Usable power-on turns are defined as throttle above 60%, brake below 10%, and
absolute yaw rate above 5 deg/s. They cover 198.82 seconds. Rear speeds differ
by less than 0.01 rad/s for **94.42%** of those samples. The clutch is therefore
often holding equal rear speeds under power, despite being capable of allowing
different speeds under lower torque. This percentage excludes straight driving.

During those power-on turns, at least one rear tyre exceeds +12% longitudinal
slip for 14.72 seconds: both tyres do so for 9.40 seconds, and only one for
5.32 seconds. Twelve percent is a diagnostic threshold, not a universal tyre
force-peak threshold; lateral slip also contributes to the combined force demand.
The log shows several slides with substantial slip on both rear tyres, rather
than only an unloaded inside wheel spinning.

Under braking the rear speeds separate more frequently. Across 149.57 seconds
of usable braking, the differential reports its **drive phase for 50.11%** of
samples. This is not determined by the brake pedal: the engine/clutch can still
deliver positive axle torque while service brakes and ABS slow the wheels.
Changing the coast factor alone therefore will not affect every braking sample.
The driveline/ABS interaction is a useful target for further inspection.

For 95% of usable driving samples, absolute body sideslip is below 2.69 degrees.
There are nevertheless distinct rear breakaway events. The three most useful
examples below have no logged material wall impact in their surrounding context.

## Slide examples

At **elapsed 306.85 s**, a power exit reaches 12.51 degrees sideslip near 98 km/h.
In the preceding second, throttle is around 75% and both rear slip ratios rise
towards approximately 28% / 21%. At the peak, rear wheel speeds are equal and
rear force demand is well beyond its peak, while the front is below its peak.
Throttle reduction and countersteering bring it back, but a second excursion
follows; sustained sideslip below 3 degrees begins around 308.20 s. The car
continues forward above 26 m/s throughout that recovery.

At **elapsed 653.58 s**, another power exit reaches 13.85 degrees near 125 km/h.
Rear slip at the peak is approximately 12.4% / 14.8%, with equal rear wheel
speeds. The rear tyres are beyond their combined force peak, while the front
remains below it. The driver reduces throttle and countersteers; sustained
sideslip below 3 degrees begins approximately 0.35 seconds after the peak,
without slowing below 34.7 m/s in that interval.

![Recorded power slide](../tmp/icr2_analysis/differential_power_slide_653.png)

At **elapsed 199.10 s**, a braking/turn-in event reaches 20.84 degrees near
73 km/h. The slide begins during turn-in before the nearly full brake application
at the peak. Both rear tyres are near -12% longitudinal slip under ABS, with
large combined demand. Countersteering produces an opposite-direction yaw
response; sustained sideslip below 3 degrees begins about 0.67 seconds after
the peak. This is recoverable, but shows a substantial transient rather than
perfectly stable turn-in.

The early **94–96 s** event is different: sideslip continues beyond the filtered
44-degree sample to approximately 55 degrees as forward speed drops below
10 m/s. The car slows almost to a stop before resuming. Its later small sideslip
does not establish successful recovery at racing speed. The large excursions
around 390–396 s and 488–491 s have logged wall impacts nearby and are excluded
from conclusions about differential-only handling.

“Sustained below 3 degrees” means a continuous 0.5-second interval below that
threshold with forward speed above 10 m/s; reported times mark the beginning of
that interval. This distinguishes a brief crossing through zero from settlement.

## Next comparison

The implementation is active and permits rear-wheel separation, and several
slides are recoverable. This run does not prove it improves on the shared shaft.
The clearest tuning question is why the trial clutch holds equal rear speeds
through most power-on cornering.

Compare **10% drive / 10% coast / 20 Nm preload** against the current
**30% / 10% / 20 Nm**, keeping stagger, wings and assists unchanged. This is a
one-variable experiment, not a proven better setup. Check both inside-wheel
spin and simultaneous rear spin, corner-exit acceleration, slide frequency and
recovery; an open axle could trade reduced scrub for more inside-wheel spin.
Avoid changing the tyre grip curve on the strength of this single run.

Detailed audit: `tmp/icr2_analysis/latest_differential_audit.json`.
Analysis scripts: `tmp/icr2_analysis/audit_latest_differential.py` and
`tmp/icr2_analysis/summarize_differential_laps.py`. Original telemetry was read
without modification.
