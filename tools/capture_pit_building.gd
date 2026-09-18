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
	camera.near = .1
	camera.fov = 55.0
	camera.make_current()
	var views := [
		["pit_building_overview",Vector3(100,42,135),Vector3(20,1.8,58)],
		["pit_building_front",Vector3(5,4.5,85),Vector3(-4,1.9,67)],
		["pit_building_rear",Vector3(-53,16,18),Vector3(10,2,58)],
	]
	for view in views:
		camera.position = track.global_position+view[1]
		camera.look_at(track.global_position+view[2])
		for i in range(16):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/%s.png" % view[0])
	print("PIT BUILDING CAPTURES COMPLETE")
	quit()
