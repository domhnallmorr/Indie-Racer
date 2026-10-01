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
	camera.far = 3000
	camera.make_current()
	camera.position = track.global_position + Vector3(-132, 11, -100)
	camera.look_at(track.global_position + Vector3(-145, 5, -81))
	await save_view("tv_platform_detail")
	camera.position = track.global_position + Vector3(30, 170, -210)
	camera.look_at(track.global_position + Vector3(0, 0, -60))
	await save_view("tv_platform_backstraight")
	print("TV camera platform detail and backstraight views captured.")
	quit()

func save_view(label: String) -> void:
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/" + label + ".png")

