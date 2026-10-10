extends RefCounted
## Reduce only level, straight two-row ribbons. Bank/transition faces stay exact.
## Input comes from the runtime mesh collider, preserving its float precision.
const STRIP_VERTICES := 8*6
const EDGE_TOLERANCE_M := .0001

static func simplified_faces(source: PackedVector3Array) -> PackedVector3Array:
	if source.size()%STRIP_VERTICES != 0: return source
	var faces := PackedVector3Array()
	for index in range(0,source.size(),STRIP_VERTICES):
		var strip := source.slice(index,index+STRIP_VERTICES)
		var reduced := _level_strip(strip)
		faces.append_array(strip if reduced.is_empty() else reduced)
	return faces

static func _level_strip(strip: PackedVector3Array) -> PackedVector3Array:
	var a := strip[0]
	var b := strip[2]
	var c := strip[-1]
	var d := strip[-2]
	var across := d-a
	var other_across := c-b
	if across.length() < 1 or other_across.length() < 1: return PackedVector3Array()
	var original_area := 0.0
	for p in strip:
		if p.y != a.y: return PackedVector3Array()
		# Every source vertex must lie on one of the two original cross-track
		# edges. Reject curved/nonrectangular sampling and unexpected mesh order.
		var on_first := _on_edge(p,a,d)
		var on_second := _on_edge(p,b,c)
		if not on_first and not on_second: return PackedVector3Array()
	var normal := (strip[1]-a).cross(b-a)
	var first := (c-a).cross(b-a)
	var second := (d-a).cross(c-a)
	if first.dot(normal) <= 0 or second.dot(normal) <= 0: return PackedVector3Array()
	for i in range(0,strip.size(),3):
		var face := (strip[i+1]-strip[i]).cross(strip[i+2]-strip[i])
		if face.dot(normal) <= 0: return PackedVector3Array()
		original_area += face.length()*.5
	var reduced_area := (first.length()+second.length())*.5
	if absf(original_area-reduced_area) > maxf(.00001,original_area*.00001): return PackedVector3Array()
	return PackedVector3Array([a,c,b,a,d,c])

static func _on_edge(p: Vector3, a: Vector3, b: Vector3) -> bool:
	var edge := b-a
	var t := (p-a).dot(edge)/edge.length_squared()
	return t >= 0 and t <= 1 and p.distance_to(a+edge*t) <= EDGE_TOLERANCE_M

static func apply(surface: MeshInstance3D) -> void:
	var node := surface.get_child(0).get_child(0) as CollisionShape3D
	var original := node.shape as ConcavePolygonShape3D
	if original.get_meta("indy_road_collision_simplified",false): return
	var source := original.get_faces()
	var faces := simplified_faces(source)
	if faces.size() == source.size(): return
	var shape := ConcavePolygonShape3D.new()
	shape.margin = original.margin
	shape.backface_collision = original.backface_collision
	shape.set_faces(faces)
	shape.set_meta("indy_road_collision_simplified",true)
	node.shape = shape
