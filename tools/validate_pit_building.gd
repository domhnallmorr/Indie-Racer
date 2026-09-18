extends SceneTree

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var track = load("res://content/tracks/mile_oval/scenes/track.tscn").instantiate()
	root.add_child(track)
	await physics_frame
	await physics_frame
	var space = track.get_world_3d().direct_space_state
	# The shortened ends must be open ground, including where the old block stood.
	for x in [-50.0,90.0]:
		var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,10,58),Vector3(x,-1,58)))
		assert(not hit.is_empty() and hit.position.y < .2,"Old building collision still blocks shortened end")
	var roof = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(20,10,58),Vector3(20,-1,58)))
	assert(not roof.is_empty() and absf(roof.position.y-4.65) < .02,"Expected shallow roof collision")
	var front = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(20,1,75),Vector3(20,1,58)))
	assert(not front.is_empty() and absf(front.position.z-67) < .02,"Building width changed")
	var end = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(90,1,58),Vector3(20,1,58)))
	assert(not end.is_empty() and absf(end.position.x-72.8) < .02,"Building length is not 105.6 m")
	print("PIT BUILDING CHECK PASSED: shortened ends clear, 105.6 x 18 m footprint, 4.65 m roof.")
	quit()
