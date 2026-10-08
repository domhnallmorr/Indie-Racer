extends RefCounted
## The imported road has 20 quads across each longitudinal strip. Replace only
## level rectangular strips with two triangles, using the imported collider's
## exact vertices. Keep all corner/bank-transition triangles and the visual mesh.
const VERTICES_PER_STRIP := 20*2*3

static func apply(surface: MeshInstance3D) -> void:
	for node in surface.find_children("*","CollisionShape3D",true,false):
		var original = node.shape
		if not original is ConcavePolygonShape3D:
			continue
		if original.get_meta("mile_road_collision_simplified",false):
			continue
		var source: PackedVector3Array = original.get_faces()
		var faces := simplified_faces(source)
		if faces.size() == source.size():
			continue
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = original.backface_collision
		shape.margin = original.margin
		shape.set_faces(faces)
		shape.set_meta("mile_road_collision_simplified",true)
		node.shape = shape

static func simplified_faces(source: PackedVector3Array) -> PackedVector3Array:
	# A changed import layout must retain the authored collider rather than
	# interpreting a partial strip as a rectangle.
	if source.size()%VERTICES_PER_STRIP != 0:
		return source
	var faces := PackedVector3Array()
	for index in range(0,source.size(),VERTICES_PER_STRIP):
		var strip := source.slice(index,index+VERTICES_PER_STRIP)
		var rectangle := _flat_rectangle(strip)
		faces.append_array(rectangle if not rectangle.is_empty() else strip)
	return faces

static func _flat_rectangle(strip: PackedVector3Array) -> PackedVector3Array:
	var bounds := AABB(strip[0],Vector3.ZERO)
	var vertices := {}
	for p in strip:
		if p.y != strip[0].y:
			return PackedVector3Array()
		bounds = bounds.expand(p)
		vertices[p] = true
	if bounds.size.x <= 0 or bounds.size.z <= 0:
		return PackedVector3Array()
	var a := bounds.position
	var b := a+Vector3(bounds.size.x,0,0)
	var c := a+Vector3(bounds.size.x,0,bounds.size.z)
	var d := a+Vector3(0,0,bounds.size.z)
	if not (vertices.has(a) and vertices.has(b) and vertices.has(c) and vertices.has(d)):
		return PackedVector3Array()
	# Do not fill a partial strip or alter a nonrectangular outline. The source
	# ribbon is a tessellated skin; its triangles must cover this rectangle.
	var area := 0.0
	for triangle in range(0,strip.size(),3):
		area += .5*(strip[triangle+1]-strip[triangle]).cross(strip[triangle+2]-strip[triangle]).length()
	if absf(area-bounds.size.x*bounds.size.z) >= maxf(.00001,area*.00001):
		return PackedVector3Array()
	# Match the imported winding, including the backstraight's reversed travel.
	if (b-a).cross(c-a).dot((strip[1]-strip[0]).cross(strip[2]-strip[0])) < 0:
		return PackedVector3Array([a,c,b,a,d,c])
	return PackedVector3Array([a,b,c,a,c,d])
