# Text spotter

The driving HUD automatically shows amber CAR LEFT / CAR RIGHT warnings when
an AI car overlaps the player's length within six metres to either side.
Cars on both sides produce THREE WIDE — HOLD YOUR LINE. After traffic clears,
a green clear call stays visible for two seconds. Warnings stay visible for
the entire overlap; they are not repeated every frame.

Sides are relative to the player's heading. Detection projects a nominal
5 m by 2 m car footprint and supports differently oriented opponents. A
0.6 m release margin and 0.4 second clearance delay reduce boundary chatter.
Hidden cars and cars more than 2.5 m above or below the player are ignored.
Opening a menu that disables driving resets and hides the spotter.

`game/race/spotter.gd` owns detection and emits `callout(message, occupied_sides)`
on transitions. Future audio can subscribe to this signal. The side bitmask is
1 for left, 2 for right, 3 for both, and 0 for clear. Presentation lives in
`game/ui/spotter_hud.gd`; no sound assets are required.

Run `tools/validate_spotter.gd` with Godot's headless `--script` option for
detection checks, and `tools/validate_race_ui.gd` for HUD/menu integration.
