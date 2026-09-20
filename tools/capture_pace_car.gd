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
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.fov = 52
	camera.far = 2000
	camera.make_current()
	var car = scene.pace_car
	camera.global_position = car.to_global(Vector3(-5,3,-6))
	camera.look_at(car.global_position+Vector3(0,.8,0))
	for i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/pace_car_bay.png")
	quit()
