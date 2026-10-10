# Physics-rate follow-up: laps, grip limits, contacts and AI cost

Keep the project at 120 Hz. The longer tests do not establish that a global
60 Hz change preserves handling, although they also do not establish a
perceptible 120 Hz handling advantage. AI collision and grounding remain
the next performance targets.

## Full-lap method

`tools/compare_track_lap_rates.gd` uses the actual player car on each track,
without traffic. A route pilot drives at 60 Hz and records its controls. A
fresh car then replays those exact inputs at 60 and 120 Hz, holding each input
for the same 1/60 s. Primitive car/model/suspension/player-state variables,
pose and velocity are restored; live node references remain attached to the
fresh scene. The 60 Hz replay verifies that this restoration is sufficiently
close before interpreting a different-rate replay.

An independent 120 Hz run lets the same pilot correct its steering at that
rate. This separates accumulated open-loop trajectory divergence from the
ability to drive a lap. The initial state is placed 100 m along the race line,
settled for two seconds, then starts at 60 m/s. Engine time scale is 1 and
engine collision delta matches model delta. `--fixed-fps 240` accelerates
headless execution; its timing is not displayed FPS.

The lap is measured from the deployed starting pose to the pilot's first
route wrap, not official start-line-to-start-line timing. Severe-spin/reverse
attempts terminate after at least ten seconds, with a 180 s maximum. A finite
simulation exit is not a handling pass. The current pilot cannot complete
every track, so failed attempts cannot establish full-lap equivalence.

| Track / input scenario | 60 Hz feedback run | 120 Hz feedback run | Fixed-input replay finding |
| --- | --- | --- | --- |
| Indy, normal | Completes in 45.567 s; 1 wall event | Completes in 45.558 s; 2 wall events | 120 Hz input replay eventually leaves the line and crashes |
| Indy, steering/lift stress | Completes in 45.617 s; 2 wall events | Completes in 45.608 s; 2 wall events | 120 Hz input replay eventually leaves the line and crashes |
| Michigan, normal | Completes in 36.800 s; no wall events | Completes in 36.783 s; no wall events | 120 Hz stays within 0.554 m / 0.0118 degrees / 0.0245 km/h of the recording |
| Texas, normal planner | Severe spin; attempt stops at 18.917 s | Severe spin; attempt stops at 18.875 s | Similar onset; failed pilot fixture, not a full lap |
| Texas, steering/lift stress plus higher corner target | Completes in 26.617 s; no wall events | Completes in 26.608 s; no wall events | 120 Hz stays within 0.440 m / 0.0890 degrees / 0.218 km/h of the recording |
| Mile Oval, normal | Severe spin/reverse; attempt stops at 10.033 s | Severe spin/reverse; attempt stops at 10.017 s | Failed pilot fixture |
| Surfers, normal | Severe spin/reverse; attempt stops at 10.033 s | Severe spin/reverse; attempt stops at 10.017 s | Failed pilot fixture |

The stress scenario uses `--utilisation=1.05`, increases normalized steering
by a smooth pulse of up to 35% at 12–13 seconds, then lifts at 13–13.4 seconds.
The 120 Hz fixed-input replay receives the already modified recorded controls;
the pulse is not applied twice. Raising the planner's utilization alone did
not change Indy because the simple planner was already power-limited there.
The pulse tests additional demand and recovery; the resulting roughly
2.3-degree Indy sideslip is not proof that this road fixture reaches peak grip.
Texas's changed planner avoids the spin seen in its normal run; this is a
fixture difference, not evidence that higher demand is generally safer.

For normal Indy, fixed-input 60/120 trajectories separate by 0.1 m at 3.683 s,
1 m at 8.933 s, 5 m at 12.567 s, and 20 m at 26.133 s. After leaving the line,
wall impacts and discontinuous support dominate; large post-crash wheel-load
peaks are not useful suspension accuracy statistics. This invalidates an
assumption that the earlier short-replay similarity guarantees whole-lap
interchangeability. Both feedback-driven rates nevertheless complete Indy
with close timings and similar peak sideslip (2.30/2.31 degrees).

The 60 Hz restoration control stays within 0.001 m on Indy, 0.024 m on
Michigan and 0.019 m on the successful Texas stress lap. Scene reconstruction
does not restore the physics server's hidden contact state, so exact bitwise
reproduction is not claimed. Automated route pilots are not human feel tests.

## Grip-limit isolation

`tools/compare_grip_limit_rates.gd` exercises the internally substepped tyre
and drivetrain model at 60, 120 and 240 Hz, on constant flat support, starting
at 25 m/s in second gear. Mirrored controls hold two degrees of road-wheel
steering, increase throttle after one second, and either keep applying power
or lift/countersteer after three seconds. All rates produce a severe slide,
with breakaway above two degrees of sideslip at 1.4333 s. Peak rear slip is
84.5113/84.5112/84.5109 degrees. The mirrored results agree and remain finite.

This is a deliberately late recovery after a developed spin, not a successful
early driver catch. It demonstrates close core-model rate agreement under
large slip; it does not exercise real road sampling, banking or collisions.
That distinction is consistent with the existing internal 0.5 ms substeps.

## Car and wall contacts

`tools/compare_car_contact_rates.gd` and
`tools/compare_wall_contact_rates.gd` adapt the existing body-sweep fixtures.
At each of 60/120/240 Hz, the engine tick and model timestep agree and scenario
durations remain constant. Car contact-count limits scale with cadence.
Practice mode explicitly loads the test roster so opponents exist. The slow
wall-contact gap scales with the incoming sweep distance, ensuring the
0.2 m/s sweep actually reaches the wall even at 240 Hz.

All car-contact cases pass at every cadence with Mile Oval, Indy, Texas and
Surfers configurations: AI rear/side contact, player/AI contact, separation,
momentum and arena barriers. These use a common artificial level arena with
track-specific configurations, not each track's racing surface. The wall
suite passes at all three rates, including real straight/banked Mile Oval
walls and glancing/head-on/high-speed/reverse/gentle impacts. Real track walls
on the other tracks have not been asserted by this suite.

Earlier unchanged fixtures failed while using a hard-coded 1/60 s drive step
against the project's 120 Hz engine collision tick. The new matched-timestep
fixtures pass; those older failures should not be treated as confirmed runtime
contact regressions. The runtime contact implementation remains unchanged.

## AI timing

The existing Indy full-field fixture measures instrumented AI movement,
surface-step attempts and visual grounding at both 60 and 120 Hz. Runs are
sequential after the physics comparisons finish, with twenty seconds sampled
after ten seconds of warmup. Results are in
`builds/indy_ai_instrumented_{60,120}.json`. They are headless, instrumented
source-game timings, not release FPS; nested timer categories overlap.

| Field timer | 120 Hz ms per tick | 60 Hz ms per tick | 120 Hz ms per simulated second | 60 Hz ms per simulated second |
| --- | ---: | ---: | ---: | ---: |
| Driver total | 5.242 | 6.328 | 629.1 | 379.7 |
| Vehicle movement, included in total | 4.200 | 4.939 | 504.0 | 296.4 |
| Contact movement, included in movement | 3.314 | 4.013 | 397.7 | 240.8 |
| Surface-step attempts, included in contacts | 1.743 | 1.942 | 209.2 | 116.5 |
| Visual grounding, included in movement | 0.453 | 0.471 | 54.3 | 28.3 |
| Speed planner, included in total | 0.050 | 0.092 | 5.9 | 5.5 |

All twenty AI finish grounded at both cadences; player speed is about
315.2 km/h. Contact movement consumes about 63% of the measured driver total;
surface-step attempts alone consume about 33%, and visual grounding about 9%.
These percentages are not additive because surface steps occur inside contact
movement. The sequential runs provide a direction for optimization, not a
precise release-frame budget: instrumentation and headless/debug execution
affect wall timing. AI total cost per simulated second falls about 40% at
60 Hz, rather than exactly halving; each lower-rate movement sweep is longer.

First investigate avoiding unnecessary AI surface-step sweeps on continuous
road, with bank/transition/contact equivalence checks. Grounding can also be
considered for a lower update rate with smooth visuals, but even eliminating
its measured cost entirely would save less than the surface-step category.
Do not halve AI movement ticks by merely passing a larger delta: Godot's
`move_and_slide` uses the engine physics delta, so that would repeat the
timestep mismatch corrected in the diagnostic fixtures.

## Reproduction and artifacts

From the project directory, using the installed Godot console executable:

```powershell
godot --headless --path . --fixed-fps 240 --script tools/compare_track_lap_rates.gd -- --track=indianapolis
godot --headless --path . --fixed-fps 240 --script tools/compare_track_lap_rates.gd -- --track=texas --utilisation=1.05
godot --headless --path . --script tools/compare_grip_limit_rates.gd
godot --headless --path . --fixed-fps 240 --script tools/compare_car_contact_rates.gd -- --track=indianapolis --hz=120
godot --headless --path . --fixed-fps 240 --script tools/compare_wall_contact_rates.gd -- --hz=120
godot --headless --path . --fixed-fps 240 tools/profile_indy_practice.tscn -- --hz=120 --seconds=20 --warmup=10 --instrument --moving-player --output=res://builds/indy_ai_instrumented_120.json
```

Lap control sequences and common-time samples are in
`builds/lap_rates_<track>_<utilisation-percent>.json`, with paired `.log` files.
Grip-limit output is `builds/grip_limit_rates.json`; contact logs are
`builds/{car,wall}_contact_rates_<track>_<rate>.log`. Logs were checked for script
errors. ObjectDB exit-leak warnings inherited from fixture/scene teardown occur
in some runs; they are not used as gameplay performance evidence.

Only diagnostic tools and documentation change in this follow-up. The default
physics cadence, AI scheduling and runtime handling remain unchanged.
