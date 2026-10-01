extends SceneTree
func _initialize() -> void:
	call_deferred("validate")
func validate() -> void:
	var track: Node3D = load("res://content/tracks/texas/scenes/track.tscn").instantiate()
	root.add_child(track)
	await physics_frame
	await physics_frame
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/texas/ai/reference_paths.json"))
	var path: Array = data.reference_path
	for i in range(0,path.size()-1,8):
		var p: Array = path[i]
		var at := Vector3(p[0],p[1],p[2])
		var hit := root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*12,at-Vector3.UP*12))
		assert(not hit.is_empty(), "Missing racing surface")
		assert(absf(hit.position.y-at.y) < .015, "Reference height differs from collision")
	for sample in [[333,20.0],[874,24.0],[600,5.0],[0,5.0]]:
		var p: Array = path[sample[0]]
		var at := Vector3(p[0],p[1],p[2])
		var hit := root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*12,at-Vector3.UP*12))
		var angle := rad_to_deg(acos(clampf(hit.normal.y,-1,1)))
		assert(absf(angle-sample[1]) < .2)
		print("BANK ",sample[0]," = ",angle)
	var fence = track.get_node("CatchFence")
	for i in range(fence._wall.size()-1):
		var row: Array = fence._wall[i]
		var s: float = 2414.016*i/(fence._wall.size()-1)
		var expected := (Vector3(row[2][0],row[2][1],row[2][2])+Vector3(row[3][0],row[3][1],row[3][2]))*.5
		assert(fence._point(s,0).distance_to(expected) < .005)
	print("PASS: banking peaks, 5-degree straights, racing path/collision agreement and fence alignment")
	quit()
