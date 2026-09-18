extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var scene = load("res://game/main/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.get_node("HUD").hide()
	var track = scene.get_node("MileOval")
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.far = 2000
	camera.near = 2.0
	camera.fov = 48.0
	camera.make_current()
	camera.position = track.global_position + Vector3(0,560,160)
	camera.look_at(track.global_position)
	for i in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/infield_overview.png")
	print("INFIELD CAPTURE COMPLETE")
	quit()
