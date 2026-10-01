# Wheel animation and tyre lettering

The shared vehicle scene includes `game/vehicle/wheel_visuals.gd`, so player and
AI cars use the same visual animation. Each named wheel spins around its existing
hub on local X, carrying its rim assembly and both sidewall markings. Signed
vehicle speed divided by the mesh-derived tyre radius drives the angle; stopping
stops the animation and reversing reverses it. This is a road-speed visual effect,
not a simulation of independent wheel slip or locked brakes.

The curved cream-white Firestone text appears twice per sidewall, on both inner
and outer faces. It uses one shared alpha-cut material and texture, with no changes
to the imported GLB or body livery. `tools/build_tyre_branding.ps1` regenerates this
typographic approximation using Times New Roman Bold Italic; it is not an official
Firestone logo asset.

Run `tools/validate_wheel_visuals.gd` with Godot to check all four hubs, inner and
outer markings, forward/reverse rotation, stationary behaviour and one complete
revolution. A non-headless run also captures the inner sidewall, whole car and a
quarter-turn comparison in `builds/tyre_*.png`.
