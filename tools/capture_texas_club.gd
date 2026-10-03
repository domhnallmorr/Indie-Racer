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
	var club: Node3D = track.get_node("SpeedwayClub")
	camera.position = club.to_global(Vector3(-45,36,-125))
	camera.look_at(club.to_global(Vector3(0,27,25)))
	camera.make_current()
	for i in range(8): await process_frame
	assert(club.get_node("ClubSign").text == "THE SPEEDWAY CLUB")
	assert(club.get_child_count() == 9)
	print("CLUB: eight material meshes, sign and Turn 1 placement loaded")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/texas_speedway_club.png")
		camera.position = Vector3(120,430,560)
		camera.look_at(Vector3.ZERO)
		for i in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/texas_club_overview.png")
	print("PASS: Texas Speedway Club scene loaded")
	quit()
