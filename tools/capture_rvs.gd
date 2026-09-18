extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://game/main/main.tscn").instantiate()
	scene.ai_enabled = false
	root.add_child(scene)
	await process_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.get_node("HUD").hide()
	var track = scene.get_node("MileOval")
	var camping = track.get_node("InfieldCamping")
	assert(camping.placements.size() == 30)
	assert(camping.model_meshes.size() == 5)
	for batch in camping.get_children():
		assert(batch.multimesh.instance_count == 6)
		var vertices: PackedVector3Array = batch.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i in range(batch.multimesh.instance_count):
			var pose: Transform3D = batch.multimesh.get_instance_transform(i)
			for vertex in vertices:
				var p: Vector3 = pose * vertex
				var center_x := clampf(p.x,-camping.HALF_STRAIGHT,camping.HALF_STRAIGHT)
				assert(Vector2(p.x-center_x,p.z).length() < 85.0,"Campsite must clear the inner wall at radius 87 m")
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.far = 2000
	camera.near = 0.5
	camera.fov = 48.0
	camera.make_current()
	camera.position = track.global_position + Vector3(0,520,190)
	camera.look_at(track.global_position)
	await save_view("rvs_overview")
	camera.position = track.global_position + Vector3(13,17,-124)
	camera.look_at(track.global_position + Vector3(-6,1.5,-91))
	await save_view("rvs_backstraight")
	var lineup := Node3D.new()
	scene.add_child(lineup)
	for i in range(5):
		var rv := MeshInstance3D.new()
		rv.mesh = camping.model_meshes[i]
		lineup.add_child(rv)
		rv.position = track.global_position + Vector3((i-2)*9,0,220)
	camera.position = track.global_position + Vector3(24,18,183)
	camera.look_at(track.global_position + Vector3(0,1.6,220))
	camera.fov = 62
	await save_view("rvs_selection")
	print("RV CAPTURE PASSED: five shared models, six instances each, thirty campsites.")
	quit()

func save_view(label: String) -> void:
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/" + label + ".png")
