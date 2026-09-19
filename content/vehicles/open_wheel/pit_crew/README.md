# Player pit-box marker

`pit_marker.gd` builds one static crew member with human proportions, a shaped continuous torso, tapered suit sleeves/trousers, subtle fabric creases, rounded work boots, articulated gloved fingers, and a curved full-face helmet/visor. A muted red suit, white gloves and helmet, zipper, seams, belt radio and cable replace the original block-shaped design. The raised open hand remains the pit-box cue. All parts are combined into one smooth-shaded, vertex-coloured mesh.

`practice.gd` creates the marker after loading the selected track session in both practice and race modes. `configure()` uses the same pit-box transform and assigned ID as the player: 3.7 m ahead of the box centre and 1.7 m toward the infield side, facing arriving traffic. This follows configuration changes instead of hard-coding the current box's world coordinates. The figure sits beside the car's departure path and has no blocking collision or servicing logic.

Run Godot with `--path . --script tools/capture_pit_crew.gd` to check the assignment/offset and capture a close-up and pit-lane approach in `builds/`.
