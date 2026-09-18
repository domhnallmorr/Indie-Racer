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
	camera.make_current()
	camera.position = track.global_position + Vector3(88,15,112)
	camera.look_at(track.global_position + Vector3(69,14,77))
	for i in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/flagpole.png")
	print("FLAG CAPTURE COMPLETE")
	quit()
