extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var track = load("res://content/tracks/indianapolis/scenes/track.tscn").instantiate()
	root.add_child(track)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-35,0)
	root.add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("9babbb")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .65
	root.add_child(environment)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.far = 5000
	var pylon: Node3D = track.get_node("ScoringPylon")
	var forward := -pylon.basis.z
	var inside := pylon.basis.x
	for view in [["overview",-150.0,-38.0,36.0],["driver",-100.0,10.0,1.4]]:
		camera.position = pylon.position+forward*float(view[1])+inside*float(view[2])+Vector3.UP*float(view[3])
		camera.look_at(pylon.position+Vector3.UP*(9 if view[0] == "overview" else 10))
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/indianapolis_pits_"+str(view[0])+".png")
	var pagoda: Node3D = track.get_node("Pagoda")
	for view in [["pagoda",Vector3(65,22,12),Vector3(0,23,0)],
		["bricks",Vector3(65,7,6),Vector3(43,0,0)]]:
		camera.position = pagoda.to_global(view[1])
		camera.look_at(pagoda.to_global(view[2]))
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/indianapolis_"+str(view[0])+".png")
	var suites: Node3D = track.get_node("Turn2Suites")
	assert(suites.find_children("*","CollisionObject3D",true,false).is_empty())
	assert(suites.find_children("*","MeshInstance3D",true,false).size() == 9)
	for view in [["suites",Vector3(-110,15,0),Vector3(0,8,0)],
		["suites_trackside",Vector3(-27,2,105),Vector3(-5,8,0)]]:
		camera.fov = 42 if view[0] == "suites" else 75
		camera.position = suites.to_global(view[1])
		if view[0] == "suites_trackside":
			var paths: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/indianapolis/ai/reference_paths.json"))
			var p: Array = paths.reference_path[int(1220.0/4023.36*(paths.reference_path.size()-1))]
			camera.position = Vector3(p[0],p[1]+1.5,p[2])
		camera.look_at(suites.to_global(view[2]))
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/indianapolis_"+str(view[0])+".png")
	print("INDIANAPOLIS SUITES: 9 material batches, no collision bodies; exterior/trackside captured")
	var trees = track.get_node("BackstretchTrees")
	assert(trees.placements.size() == 51)
	assert(trees.find_children("*","CollisionObject3D",true,false).is_empty())
	var paths: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/indianapolis/ai/reference_paths.json"))
	var origin: Array = paths.reference_path[int(1550.0/4023.36*(paths.reference_path.size()-1))]
	var target: Array = paths.reference_path[int(1800.0/4023.36*(paths.reference_path.size()-1))]
	camera.fov = 65
	camera.position = Vector3(origin[0],origin[1]+4,origin[2])
	camera.look_at(Vector3(target[0],target[1]+7,target[2]))
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/indianapolis_backstretch_trees.png")
	print("INDIANAPOLIS TREES: 51 trees, 10 shared mesh batches, no collision bodies")
	track.free()
	quit()
