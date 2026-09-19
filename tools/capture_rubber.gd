extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://game/main/main.tscn").instantiate()
	scene.ai_enabled = false
	root.add_child(scene)
	await process_frame
	scene.get_node("HUD").hide()
	var track = scene.get_node("MileOval")
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.far = 2000.0
	camera.near = .1
	camera.fov = 52.0
	camera.make_current()
	for view in [
		["rubber_t1_t2",Vector3(255,75,152),Vector3(305,0,14)],
		["rubber_t3_t4",Vector3(-255,75,-152),Vector3(-305,0,-14)],
		["rubber_driver",Vector3(320,4,50),Vector3(330,1,-18)],
		["rubber_straight",Vector3(-40,15,105),Vector3(90,0,126)],
	]:
		camera.position = track.global_position+view[1]
		camera.look_at(track.global_position+view[2])
		for i in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/%s.png" % view[0])
	print("RUBBER CAPTURES COMPLETE")
	quit()
