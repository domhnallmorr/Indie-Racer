extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://game/main/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.get_node("HUD").hide()
	var track = scene.get_node("MileOval")
	var crew = track.get_node("PlayerPitCrew")
	var pose: Transform3D = scene.track_data.pit_box_transform()
	var relative: Vector3 = pose.affine_inverse()*crew.position
	assert(relative.is_equal_approx(Vector3(-1.7,0,-3.7)))
	assert(crew.get_meta("pit_box_id") == scene.player_state.assigned_pit_box_id)
	assert(crew.find_children("*","CollisionObject3D",true,false).is_empty())
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.far = 1500.0
	camera.near = .05
	camera.fov = 52.0
	camera.cull_mask = 3
	camera.make_current()
	for view in [
		["pit_crew_detail",Vector3(-4,2.2,3),Vector3(0,1,0)],
		["pit_crew_approach",Vector3(-20,1.1,8),Vector3(1,.9,1)],
	]:
		camera.global_position = crew.global_position+view[1]
		camera.look_at(crew.global_position+view[2])
		for i in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/%s.png" % view[0])
	print("PIT CREW CHECK PASSED: assigned player box, front/infield offset, no blocking collision. Captures complete.")
	quit()
