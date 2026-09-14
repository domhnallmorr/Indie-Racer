# Grandstand scenery

Ten identical roofless triangular wedges, 32 m wide, 18 m deep, 9 m tall. Five run from the turn 4 exit to the existing main stand; five follow turn 1. Each is oriented toward the local track centreline. All share one mesh and material, with crowd UVs in the top half of the atlas and steel support UVs in the bottom half.

`grandstands.gd` builds the scenery in both the editor and the game. It also centres the seven original main-stand rows at the finish line (track-local X = 61.796 m). The Blender source generator uses this updated position too. The track GLB and driving geometry need no rebuild for this scenery addition.

Texture: `crowd_support_atlas.png`, generated using the built-in imagegen tool. Original output is retained without image processing.

## Generation prompt

Use case: stylized-concept. Create a single square game texture atlas for late 1990s racing game grandstands, 1024x1024. Top half is a seamless repeating crowd seating texture, flat front-on orthographic view of exactly eight horizontal packed rows of tiny low resolution spectators, coloured shirts red blue white yellow, small heads, dark gaps and grey bench strips. No perspective, no stadium outline, no roof, no sky, fills the entire top half edge to edge. Bottom half is a flat orthographic repeating steel grandstand support facade texture: grey vertical steel posts, horizontal beams and diagonal X braces over dark charcoal shadow background, four identical bays across, subtle worn metal, no perspective. Hard straight division at exactly halfway. Pixel art / low resolution 1997 PC racing simulator aesthetic, readable coarse pixel clusters, no text or logos. Both halves individually tile horizontally.

## Visual check

Run Godot with `--path . --script res://tools/capture_grandstands.gd` to verify stand counts and main-stand alignment, and save trackside and overhead previews in `builds/`.

## Covered main grandstand

main_grandstand.gd adds a 264 m shallow canopy, slender front/rear pillars with diagonal braces, ten crowd bays and aisles, and a central 76 m windowed booth enclosure. It uses the user's supplied 2002 race screenshot as a visual reference; proportions and booth function are approximations, not verified 1995 architecture. Existing finish-line alignment, seven underlying seating rows and the ten separate open stands are retained. Crowd texture reuses the existing atlas; roof, steelwork and windows use simple matte materials. No physics changes.

Validate and render with tools/capture_main_grandstand.gd. Previews: builds/main_grandstand_trackside.png and builds/main_grandstand_overview.png.
