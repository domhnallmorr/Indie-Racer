extends SceneTree
## Compare actual ray support across every imported road triangle and the road
## edges; bank faces and visual resources must survive the collider replacement.
const RoadCollision = preload("res://content/tracks/mile_oval/surface/road_collision.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message)

func road_shape(geometry: Node) -> CollisionShape3D:
	for node in geometry.find_children("*","CollisionShape3D",true,false):
		if "RacingSurface" in str(geometry.get_path_to(node)): return node
	return null

func sample(points: PackedVector3Array,road: CollisionShape3D,excluded: Array[RID]) -> Array:
	var results: Array = []
	var query := PhysicsRayQueryParameters3D.new()
	query.exclude = excluded
	for point in points:
		query.from = point+Vector3.UP*.5
		query.to = point-Vector3.UP*.5
		var hit := road.get_world_3d().direct_space_state.intersect_ray(query)
		results.append({} if hit.is_empty() else {"position":hit.position,"normal":hit.normal,"road":hit.collider == road.get_parent()})
	return results

func validate() -> void:
	root.set_meta("roster_selection",{"track_id":"mile_oval","file":"res://content/rosters/icr2_test/manifest.json","seed":42})
	var imported = load("res://content/tracks/mile_oval/models/mile_oval.glb").instantiate()
	var original: ConcavePolygonShape3D = road_shape(imported).shape
	var source := original.get_faces()
	var original_visual: Mesh = imported.get_node("RacingSurface").mesh
	imported.free()
	var main = load("res://game/main/main.tscn").instantiate()
	main.ai_telemetry_enabled = false
	root.add_child(main)
	for body in main.find_children("*","CollisionObject3D",true,false): body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var road := road_shape(main.player.track)
	var optimized: ConcavePolygonShape3D = road.shape
	var faces := optimized.get_faces()
	check(source.size()/3 == 32200,"Fixture must use the authored 20-column Mile road")
	check(faces.size()/3 == 16658,"Flat strips must remove 15,542 collision triangles")
	check(optimized.margin == original.margin and optimized.backface_collision == original.backface_collision,"Collision properties must be preserved")
	var surface := road.get_parent().get_parent() as MeshInstance3D
	check(surface.mesh == original_visual,"The visible road mesh must be the original imported resource")
	RoadCollision.apply(surface)
	check(road.shape == optimized,"Repeated setup must retain the already simplified collider")
	check(RoadCollision.simplified_faces(source.slice(0,source.size()-3)) == source.slice(0,source.size()-3),"An incomplete import layout must retain its geometry")
	var face_set := {}
	for i in range(0,faces.size(),3): face_set[[faces[i],faces[i+1],faces[i+2]]] = true
	var bank_faces := 0
	for i in range(0,source.size(),3):
		if source[i].y != source[i+1].y or source[i].y != source[i+2].y:
			bank_faces += 1
			check(face_set.has([source[i],source[i+1],source[i+2]]),"Bank/transition triangle changed at "+str(i/3))
	var points := PackedVector3Array()
	for i in range(0,source.size(),3): points.append(road.global_transform*((source[i]+source[i+1]+source[i+2])/3.0))
	# Inside/outside both edges of both straights. Include rays immediately
	# beside the apron and outer wall, excluding those separate colliders.
	for z in [114.995,115.005,134.995,135.005,-114.995,-115.005,-134.995,-135.005]:
		points.append(main.player.track.to_global(Vector3(0,0,z)))
	var excluded: Array[RID] = []
	for body in main.find_children("*","CollisionObject3D",true,false):
		if body != road.get_parent(): excluded.append(body.get_rid())
	road.shape = original
	await physics_frame
	await physics_frame
	var before := sample(points,road,excluded)
	road.shape = optimized
	await physics_frame
	await physics_frame
	var after := sample(points,road,excluded)
	var max_height_error := 0.0
	var max_normal_error := 0.0
	for i in range(points.size()):
		check(before[i].is_empty() == after[i].is_empty(),"Road coverage changed at "+str(points[i]))
		if before[i].is_empty() or after[i].is_empty():
			if i < source.size()/3: check(false,"Road triangle has no support at "+str(points[i]))
			continue
		check(before[i].road and after[i].road,"Ray must hit the road collider")
		var height_error: float = before[i].position.distance_to(after[i].position)
		var normal_error: float = before[i].normal.distance_to(after[i].normal)
		max_height_error = maxf(max_height_error,height_error)
		max_normal_error = maxf(max_normal_error,normal_error)
		check(height_error < .00001 and normal_error < .00001,"Road support changed at "+str(points[i]))
	main.free()
	for failure in failures: push_error(failure)
	print("MILE ROAD COLLISION rays=",points.size()," bank_faces=",bank_faces," max_height_error=",max_height_error," max_normal_error=",max_normal_error)
	print("MILE ROAD COLLISION PASSED" if failures.is_empty() else "MILE ROAD COLLISION FAILED")
	quit(0 if failures.is_empty() else 1)
