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
	camera.far = 2000.0
	camera.near = 0.1
	camera.fov = 58.0
	camera.make_current()
	var views := [
		["walls_t2", Vector3(200, 2.7, -122), Vector3(190, .5, -135.5)],
		["walls_t4", Vector3(-200, 2.7, 122), Vector3(-190, .5, 135.5)],
		["walls_concrete", Vector3(20, 2.5, 99), Vector3(-4, .5, 108)],
		["walls_inner", Vector3(20, 2.5, 96), Vector3(-4, .5, 87)],
	]
	for view in views:
		camera.position = track.global_position + view[1]
		camera.look_at(track.global_position + view[2])
		for i in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/%s.png" % view[0])
	print("WALL CAPTURES COMPLETE")
	quit()
