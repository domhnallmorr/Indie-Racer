extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://game/main/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.get_node("HUD").hide()
	var track = scene.get_node("MileOval")
	var stands = track.get_node("Grandstands")
	assert(stands.get_child_count() == 10)
	var main_count := 0
	for part in track.get_node("Geometry").get_children():
		if str(part.name).begins_with("Grandstand"):
			assert(abs(part.position.x - 61.79594) < .01)
			main_count += 1
	assert(main_count == 7)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.far = 3000
	camera.make_current()
	var origin: Vector3 = track.global_position
	camera.position = origin + Vector3(-180, 25, 98)
	camera.look_at(origin + Vector3(-120, 4, 160))
	for i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/grandstands_trackside.png")
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 820
	camera.position = origin + Vector3(0, 700, 360)
	camera.look_at(origin + Vector3(0, 0, 65))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/grandstands_layout.png")
	print("GRANDSTANDS CHECK PASSED: ten matching stands, seven main-stand rows moved to finish; two views rendered.")
	quit()
