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
	camera.position = Vector3(120,430,560)
	camera.look_at(Vector3(0,0,10))
	camera.make_current()
	for i in range(8): await process_frame
	var scenery = track.get_node("PaddockScenery")
	assert(scenery.get_child_count() == 5)
	assert(scenery.get_node("TeamTransporters").multimesh.instance_count == 36)
	print("PADDOCK: 3 garages, 36 transporters; RVs: ",scenery.get_node("Motorhomes0").multimesh.instance_count+scenery.get_node("Motorhomes1").multimesh.instance_count+scenery.get_node("Motorhomes2").multimesh.instance_count)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/texas_paddock_overview.png")
		camera.position = Vector3(-55,65,204)
		camera.look_at(Vector3(-115,0,96))
		for i in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/texas_paddock_close.png")
	print("PASS: Texas paddock scene loaded")
	quit()
