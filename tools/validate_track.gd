extends SceneTree
## Run headless with --path . --script tools/validate_track.gd.

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var track = load("res://content/tracks/mile_oval/scenes/track.tscn").instantiate()
	root.add_child(track)
	await physics_frame
	await physics_frame
	var shapes = track.find_children("*", "CollisionShape3D", true, false)
	assert(shapes.size() >= 9, "Expected imported road and wall collisions")
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/mile_oval/ai/reference_paths.json"))
	var space = track.get_world_3d().direct_space_state
	for key in ["reference_path", "pit_path"]:
		for p in data[key]:
			var position = Vector3(p[0], p[1], p[2])
			var query = PhysicsRayQueryParameters3D.create(position + Vector3.UP * 10, position - Vector3.UP)
			var hit = space.intersect_ray(query)
			assert(not hit.is_empty(), "Missing collision on " + key)
			if absf(hit.position.y - position.y) >= 0.04:
				push_error("Unexpected collision height on %s at %s: %s (%s)" % [key, position, hit.position, hit.collider.get_parent().name])
				quit(1)
				return
	print("TRACK CHECK PASSED: %d collision shapes; road and pit route raycasts passed." % shapes.size())
	quit()
