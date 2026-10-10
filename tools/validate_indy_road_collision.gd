extends SceneTree
const Road = preload("res://content/tracks/indianapolis/road_collision.gd")

func _initialize() -> void:
	call_deferred("validate")

func samples(points: PackedVector3Array, body: StaticBody3D) -> Array:
	var results := []
	var query := PhysicsRayQueryParameters3D.new()
	for p in points:
		query.from = p+Vector3.UP*.5
		query.to = p-Vector3.UP*.5
		var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
		results.append({} if hit.is_empty() else {"position":hit.position,"normal":hit.normal})
	return results

func validate() -> void:
	var circuit = load("res://content/tracks/indianapolis/scenes/track.tscn").instantiate()
	root.add_child(circuit)
	var surface: MeshInstance3D = circuit.get_node("RacingSurface")
	var shape_node: CollisionShape3D = surface.get_child(0).get_child(0)
	var original: ConcavePolygonShape3D = surface.mesh.create_trimesh_shape()
	var source := original.get_faces()
	var faces := Road.simplified_faces(source)
	assert(faces.size() < source.size(),"Expected fewer level road triangles")
	var face_set := {}
	for i in range(0,faces.size(),3): face_set[[faces[i],faces[i+1],faces[i+2]]] = true
	var bank_faces := 0
	var points := PackedVector3Array()
	for i in range(0,source.size(),3):
		points.append((source[i]+source[i+1]+source[i+2])/3)
		if source[i].y != source[i+1].y or source[i].y != source[i+2].y:
			bank_faces += 1
			assert(face_set.has([source[i],source[i+1],source[i+2]]),"Bank triangle changed")
	# Sample just inside and outside every source strip's two road boundaries.
	for i in range(0,source.size(),Road.STRIP_VERTICES):
		var a := source[i]
		var b := source[i+2]
		var c := source[i+Road.STRIP_VERTICES-1]
		var d := source[i+Road.STRIP_VERTICES-2]
		var across := (d-a).normalized()
		for offset in [-.005,.005]:
			points.append((a+b)*.5+across*offset)
			points.append((c+d)*.5-across*offset)
	# Isolate the road so adjoining apron/ground cannot mask coverage changes.
	for body in circuit.find_children("*","CollisionObject3D",true,false):
		if body != shape_node.get_parent(): body.collision_layer = 0
	shape_node.shape = original
	await physics_frame
	await physics_frame
	var before := samples(points,shape_node.get_parent())
	Road.apply(surface)
	await physics_frame
	await physics_frame
	var after := samples(points,shape_node.get_parent())
	var height_error := 0.0
	var normal_error := 0.0
	for i in range(points.size()):
		assert(before[i].is_empty() == after[i].is_empty(),"Coverage changed at "+str(points[i]))
		if before[i].is_empty(): continue
		height_error = maxf(height_error,before[i].position.distance_to(after[i].position))
		normal_error = maxf(normal_error,before[i].normal.distance_to(after[i].normal))
	assert(height_error < .0001 and normal_error < .00001,"Road support changed")
	var installed := shape_node.shape
	Road.apply(surface)
	assert(shape_node.shape == installed,"Repeated setup must preserve the installed collider")
	assert(Road.simplified_faces(source.slice(0,source.size()-3)) == source.slice(0,source.size()-3))
	print("INDY ROAD PASS original_triangles=",source.size()/3," reduced_triangles=",faces.size()/3," bank_faces=",bank_faces," rays=",points.size()," height_error=",height_error," normal_error=",normal_error)
	circuit.free()
	quit()

