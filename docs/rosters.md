# AI rosters

Current Mile Oval pace is calibrated around a 22.4-second midfield lap; see
[pace calibration](ai_pace.md) for the new line, rating mapping and measured spread.
The historical calibration figures below predate this tune.

The field now uses the [two-wide racecraft prototype](racecraft.md). Faster cars
can attempt passes; the original field-calibration notes below predate overtaking.

Press **F12** in practice, choose a roster, and restart practice with it. The seed is shown in the panel: -1 rolls a new session; entering the same nonnegative seed reproduces the driver ratings. Selection survives scene restarts during this game run. Inspector exports `roster_file` and `roster_seed` set launch defaults.

Two examples are included: **Reference field** preserves the calibrated Blue/Yellow performance with named fictional drivers; **Club 1996 — 15-car test field** has five fast, five midfield and five slower fictional drivers. These are AI opponent rosters, not championship schedules. The player currently retains the existing selected player car.

The 15-car field is the launch default (16 cars including you). Cornering rating ranges run from 94–100 at the front to 40–46 at the back, with separate braking/throttle ranges and seeded variation. All use the same car specification so driver differences can be isolated. The slower group occupies the forward pit boxes and departs first, allowing the faster group to catch it. Departures remain six seconds apart, from 4 to 88 seconds, with traffic checks able to delay them. Overtaking is still pending, so faster cars can form queues behind slower cars.

The selector scrolls through the full roster. The main HUD shows four drivers plus the followed driver's name; press **9** for the full timing table and **6/7** to cycle through every AI. The two-car Reference field remains selectable for isolated comparisons.

The full-field test exposed a pit-exit queue deadlock. AI still on the pit-exit route are now handled by following rather than treated as approaching racing traffic by the merge check. Cars already racing retain priority; this is not an overtaking planner.

## Content structure

- `content/rosters/<id>/manifest.json`: schema_version 1, id, display_name, optional year, and entries.
- Each entry has a unique identifier, driver_name, number (string), team, HTML colour, car_spec path and ratings.
- `content/car_specs/*.json`: scene, ai_class and independent component paths for chassis, tires, engine, gearbox, aero and assists. Several entries/seasons can share a spec; several specs can share components. Physics CFG validation is identical to the player's. Scenes require a CharacterBody3D root and Visual child. Recolouring currently targets the existing Livery_RacingRed material.
- `<track>/ai/profiles.json`: classes keyed by ai_class, specifying cornering_utilisation, braking_utilisation and braking_margin_m. The active track comes from the practice track-session path. Every used car class requires a profile. Limits are positive fractions no greater than 1; braking margin is nonnegative metres.

Paths must remain inside `res://content/`, without traversal. Invalid references, reversed/missing rating ranges, duplicate IDs, incompatible scenes and invalid physics fail explicitly before any AI spawn. The track must supply one pit box per entry plus the player: Mile Oval has 15 AI boxes plus the player box, spaced 9.888 metres apart. Add validated session pit boxes before authoring larger fields. AI spawning has no two-car limit; 6/7 cycle backwards/forwards through every AI, wrapping at the ends.

## Ratings

Each rating is `[minimum, maximum]` within 0–100. Equal endpoints fix a characteristic. Independent seeded uniform samples are taken once per driver/session; entry order does not affect them.

| Rating | Effect |
| --- | --- |
| cornering | Track cornering utilisation multiplied by `minimum_cornering_factor`–1.0 (floor defaults to 0.8; Mile Oval uses 0.97) |
| braking | Track braking utilisation multiplied by 0.65–1.0 |
| throttle | Racing throttle-error response multiplied by 0.6–1.0; unrestricted straights still allow full throttle |
| consistency | Higher values reduce between-lap variation; 100 disables it |

At each completed lap, consistency chooses a small performance reduction, up to 3% at rating zero. Form moves gradually towards it at 0.002 per second and affects cornering/braking. It does not change physical grip, engine power or the racing line. Pit and traffic controls remain independent. Aggression, mistakes and overtaking ratings are intentionally absent until those behaviours exist.

The AI telemetry CSV has a companion CFG containing the roster path, actual seed, resolved entry/spec, sampled ratings and track profile. Reproduction assumes unchanged content and matching simulation conditions. Seed support is not a mid-race save system.

AI telemetry is **off by default**. Enable **Record AI telemetry** in F12 and restart practice to record the field, or set the `ai_telemetry_enabled` Inspector export. Player telemetry remains independently controlled by F11. AI rows are sampled at approximately 10 Hz, held in memory, then written/flushed in one-second batches staggered across cars. Normal session shutdown flushes the final partial batch; a crash may lose that final second. Logging-disabled sessions create no AI CSV/CFG files. The bottom-right FPS counter refreshes four times per second using the engine's FPS measurement; it does not write a log.

`tools/validate_ai_logging.gd` verifies default-off behaviour, deferred batch writes and final-batch preservation on normal shutdown.

## Validation

`tools/validate_rosters.gd` checks deterministic sampling, range bounds, traversal/reversed-range rejection, composition, identity, timing, selected-roster spawning and smooth form changes. `tools/validate_ai.gd` retains the two-car reference field's lap-time, line and pit regression checks. `tools/capture_roster.gd` renders the selector for visual review.

`tools/validate_full_field.gd` uses seed 1234 for a five-minute simulation: 15 distinct pit assignments, class-rating spread, camera wrapping, pit-limit compliance, traffic following and at least two timed laps per AI. The reference pace validator explicitly loads the two-car roster. Racing-line lookahead uses cached cumulative distances and binary search to avoid repeatedly walking hundreds of segments per driver; the planner test compares it against independent linear traversal including negative distances and lap wrapping.

The validated seed-1234 field all joined by 180 simulated seconds and completed 5–9 timed laps each by 300 seconds. Best laps were 24.02–24.23 s for the fast group, 24.81–25.10 s for midfield and 25.95–26.07 s for the slower group. Maximum line error stayed at approximately 4 m or less. These are observed practice times, including traffic, not guaranteed ratings-to-lap-time mappings.
