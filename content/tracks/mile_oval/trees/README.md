# Urban track trees

Ten reusable procedural 3D tree meshes with different crown proportions, heights,
branching and foliage colours. Tapered trunks, root flares, forked limbs and fine
twigs support 1,100 randomly oriented leaf sprays per variant, replacing the old
solid spherical crowns. The original vector asset `leaf_spray.svg` supplies pointed
leaves and thin stems with transparent gaps. Double-sided alpha-cut foliage uses
mipmaps and a low alpha threshold to retain coverage in distant track views.
Soft crown-oriented normals and varied muted greens break up the silhouettes.
These are visual approximations, not botanical models.
The seeded scatter covers Turn 1, Turn 2, the backstraight, Turn 3 and Turn 4.
Most planting sites contain a single tree; every eighth site has two or three.
Trunks sit 49–74 metres outside the oval centreline, clearing existing track furniture.
Trees share meshes through ten MultiMesh instances and have no collision.

Run tools/capture_trees.gd to render the planted overview, a temporary lineup of
the ten variations and a close-up (`builds/trees_detail.png`). The lineup is not
added to the track. The capture confirms 44 placements across ten shared variants.
