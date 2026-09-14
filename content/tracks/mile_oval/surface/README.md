# Asphalt surface

Procedural shader texture on racing surface, apron and pit lane. Track-local X/Z mapping follows the existing banked mesh without UV seams. Fine aggregate fades at distance to limit shimmer. Deterministic position-hashed repair patches vary in size (roughly 1–8 m by 0.7–4.7 m), rotation, clipped corners, rough edges and darkness. No repeating patch image or per-frame randomness. Original mesh geometry, collision, track markings and handling are untouched.

Shader parameters are in asphalt.gdshader. track_surface.gd applies only material overrides to named asphalt meshes. No image generation or downloaded assets used.

Revision: base asphalt lightened to warm light grey. Repair placement now uses distance along the oval and lateral offset, keeping patches aligned through turns and wrapping continuously at the lap seam. Candidate spacing increased to approximately 20 m longitudinally and occupancy reduced to 16 percent (about 75 percent fewer patches per area). Repairs are predominantly square-edged rectangles with subtle edge variation; some are 7–15 m long and 0.44–1.1 m wide. Heading variation is limited to about +/-1.7 degrees.
