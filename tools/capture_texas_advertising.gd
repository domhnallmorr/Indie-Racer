extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var track = load("res://content/tracks/texas/scenes/track.tscn").instantiate()
	root.add_child(track)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-25,0)
	sun.light_energy = 1.1
	root.add_child(sun)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("819bad")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bdcad2")
	environment.ambient_light_energy = .65
	world.environment = environment
	root.add_child(world)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.far = 2000
	camera.near = 2.0
	camera.fov = 48
	var adverts = track.get_node("Advertising")
	var pose: Transform3D = adverts.board_poses[1]
	camera.position = pose*Vector3(-15,4,-110)
	camera.look_at(pose.origin)
	camera.make_current()
	for i in range(8): await process_frame
	assert(adverts.board_poses.size() == 6)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/texas_adverts_turn12.png")
		pose = adverts.board_poses[4]
		camera.position = pose*Vector3(-20,4,-110)
		camera.look_at(pose.origin)
		for i in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/texas_adverts_turn4.png")
	print("PASS: Texas advertising scene loaded")
	quit()
