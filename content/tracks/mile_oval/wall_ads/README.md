# Wall advertising

Eight period-oriented brands: Marlboro, Target, FedEx, McDonald's, Sears, Bosch, Goodyear and Miller Lite. Marlboro is the only tobacco brand. This is a fictional period-inspired sponsor arrangement, not a reconstruction of a particular event.

Four 112 m outer-wall zones straddle Turn 1 entry, Turn 2 exit, Turn 3 entry and Turn 4 exit, with eight panels per zone. Twenty panels span the racing-facing side of the pit separator along the front straight, from 127 m to 406.75 m along the reference lap. The physical separator starts at 125 m, so the pit-entry opening stays clear. There are no ads on the infield-side wall of the pit lane, inner corners or backstraight. Each 14 m bay contains three repeated logos, for 52 panels and 156 logos overall.

Paint meshes follow the actual imported wall facets and banking profile. They sit 12–21 mm off the track-facing wall surface, within its height (1 m pit separator, 1.15 m outer wall); no collision shapes are added. Resources are shared and mesh geometry is grouped by brand. This node is independent of the existing freestanding hoardings.

FedEx, McDonald's, Sears, Bosch, Goodyear and Miller Lite reuse the existing sourced artwork, with the same crop regions: see `../hoardings/README.md` for provenance and era limitations. Marlboro and Target are simplified vector recreations for low wall signage, not downloaded official logo files. `tools/build_wall_wordmarks.py` writes their editable SVGs using outlined system fonts; runtime does not depend on those fonts.

Period reference for Marlboro and Target: Indianapolis Motor Speedway's official 2001 entry/results listing, https://www.indianapolismotorspeedway.com/events/indy500/history/historical-stats/race-stats/race-results/2001 . Brand selection does not imply those brands appeared on these exact walls.

`tools/capture_wall_ads.gd` checks counts and placement zones, then renders all five locations and an overview. Track wall geometry uses 805 facets around the 1609.344 m lap; rebuild this mapping if the imported track geometry changes.
