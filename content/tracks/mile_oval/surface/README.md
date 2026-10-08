# Asphalt surface

Procedural shader texture on racing surface, apron and pit lane. Track-local X/Z mapping follows the existing banked mesh without UV seams. Fine aggregate fades at distance to limit shimmer. Deterministic position-hashed repair patches vary in size (roughly 1–8 m by 0.7–4.7 m), rotation, clipped corners, rough edges and darkness. No repeating patch image or per-frame randomness. The shader preserves mesh geometry, track markings and handling.

Shader parameters are in asphalt.gdshader. track_surface.gd applies material overrides to named surface and wall meshes. No image generation or downloaded assets used.

## Road collision

At runtime, `track_surface.gd` calls `road_collision.gd` once at scene load. The
imported racing surface has 20 quads across each approximately 2 m strip. Level
rectangular strips become two collision triangles, reducing the current collider
from 32,200 to 16,658 triangles. The helper uses the existing collider's exact
vertices, preserves winding and collision properties, and copies all banked and
transition strips unchanged. It checks the rectangle's corners and covered area;
an unexpected strip layout retains the original detail.

The visual mesh, apron, pit lane and barriers retain their imported geometry.
Movement, surface stepping and visual grounding continue at 60 Hz. This runs on
the imported collider, so regenerating the GLB needs no separate collision asset
or bake. `tools/validate_mile_road_collision.gd` compares road support before and
after simplification.

## Corner rubber

The asphalt shader adds a subtle, softly feathered rubber groove through T1/T2 and T3/T4. `track_surface.gd` samples the authored `ai/race_line.json` into a small lateral-offset lookup texture at scene load, so the band follows the racing line rather than a fixed-radius arc. Rubber fades across the first/last 45 m of each semicircle and is zero on both straights, the apron, pit lane and track edges. Gentle longitudinal streaking breaks up the tone; existing repairs remain visible. This is a static visual treatment with no grip or physics changes.

Tune `rubber_strength` (default 0.15) and `rubber_half_width_m` (2.2 m plus soft outer falloff) in `asphalt.gdshader`. `tools/capture_rubber.gd` captures both turns, a low trackside view and the unaffected front straight into `builds/`.

## Wall finishes

`walls.gdshader` gives OuterWall warm white paint and InnerWall/PitSeparator warm grey-brown concrete. Concrete joints follow actual wall distance around corners, with approximately 6.5 m blocks (the spacing is adjusted slightly to close the oval without a partial block). Subtle mottling, aggregate and tonal variation distinguish the blocks. `block_width_m`, `concrete_color` and `paint_color` are material parameters.

Broken black rubber streaks appear only on the track-facing outer wall, from about 29 m before to 33 m after the T2 and T4 exits. Their height follows the banked wall base. These are material-only changes; imported meshes and collision remain intact. Wall mapping uses track-local metres and needs no imported UVs. Future adverts can use separate slightly offset overlay meshes (compatible with the current GL renderer), or a later shader overlay sampled after the base finish. No advert imagery is baked into the material.

Run `tools/capture_walls.gd` with Godot to capture both exits and the inner/pit concrete in `builds/`.

Revision: base asphalt lightened to warm light grey. Repair placement now uses distance along the oval and lateral offset, keeping patches aligned through turns and wrapping continuously at the lap seam. Candidate spacing increased to approximately 20 m longitudinally and occupancy reduced to 16 percent (about 75 percent fewer patches per area). Repairs are predominantly square-edged rectangles with subtle edge variation; some are 7–15 m long and 0.44–1.1 m wide. Heading variation is limited to about +/-1.7 degrees.
