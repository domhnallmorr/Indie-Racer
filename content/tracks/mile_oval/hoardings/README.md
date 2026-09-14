# Turn 2 advertising hoardings

Three 24 x 8 metre panels on simple steel posts, following the outside of turn 2. Arc distances past turn 1 entry: 230, 270 and 310 metres. The final grandstand is at 180 metres. Panels face inward and are 17 metres outside the reference line. Visual scenery only.

## Logo sources and preparation

- FedEx: purple/orange arrow wordmark introduced in 1994. Source SVG: https://commons.wikimedia.org/wiki/File:FedEx_Corporation_-_2016_Logo.svg . This newer corporate lockup contains the earlier wordmark; fedex_1994.svg crops out the later Corporation subtitle using the SVG viewBox. Original retained as fedex.svg. History: https://peoplesgdarchive.org/item/17746/fedex-logo-design-1994
- Sears: actual 1994–2004 uppercase striped blue wordmark, downloaded unchanged: https://commons.wikimedia.org/wiki/File:Large_Sears_logo_1994-2004.png
- McDonalds: golden arches sourced from https://commons.wikimedia.org/wiki/File:McDonald%27s_Golden_Arches.svg . mcdonalds_1993.svg adds a black offset shadow to recreate the 1993-era treatment, displayed on a red panel. This is an adaptation of the sourced vector, not a scanned historical sign. Original retained as arches.svg. Era reference: https://www.youtube.com/watch?v=SdWwX6SYiDE

No image generation used. SVG variants are editable source assets. Logos use nearest sampling with mipmaps to match the game's retro texture style.

Run tools/capture_hoardings.gd through Godot to check loading and capture builds/hoardings_turn2.png.

## Expanded sponsor rows

The set now contains nine brands, repeated at turn 2 exit and turn 3 entrance (18 panels). Centre spacing is 27 m along the reference path, leaving 3 m gaps on straights and slightly more on the outside of curves. The turn 2 row starts at straight_length + 230 m and continues onto the back straight. The turn 3 row begins 140 m before corner entry and continues 76 m into the corner. Meshes and materials are shared between the two sets.

Additional sources:
- Bosch: 1981–2002 logo, https://logos-world.net/bosch-logo/ ; original PNG retained, padded edges excluded through material UV coordinates.
- Milwaukee Journal Sentinel: https://commons.wikimedia.org/wiki/File:Milwaukee_Journal_Sentinel_logo.svg ; this is a modern digitisation, recoloured black. Exact 1995 masthead fidelity is not verified.
- PPG: https://commons.wikimedia.org/wiki/File:PPG_Logo.svg ; blue PPG emblem, no modern slogan.
- UniFirst U1st: https://seeklogo.com/vector-logo/145061/unifirst ; sourced U1st artwork with a separate UniFirst name caption. The exact date of this digitisation is not independently verified.
- Goodyear: https://logos-world.net/goodyear-logo/ ; yellow italic wingfoot wordmark on blue, from the 2023 source image (before the 2025 redesign).
- Miller Lite: https://seeklogo.com/vector-logo/92777/miller-lite ; monochrome Lite wordmark with Miller eagle crest, rather than the later italic oval treatment. Exact year of the source artwork is not independently verified.

No generated logo substitutes. The original raster files are unmodified; material UV windows trim padding. Capture script checks 18 boards and shared logo meshes, and renders both track rows plus a front-on logo sheet.

Update: the turn 3 row has subsequently moved 200 m forward, now beginning 60 m after turn 3 entry and ending 276 m after entry. Spacing remains 27 m.
