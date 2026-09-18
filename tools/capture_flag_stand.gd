extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://game/main/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.get_node("HUD").hide()
	var track = scene.get_node("MileOval")
	for node in track.get_node("Geometry").find_children("GridSlot*","MeshInstance3D",true,false):
		assert(not node.visible,"Standing-start grid slot remains visible")
	var stand = track.get_node("StarterFlagStand")
	assert(absf(stand.position.x-62.49594)<.01)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.far = 2000.0
	camera.near = .1
	camera.fov = 58.0
	camera.make_current()
	for view in [
		["flag_stand",Vector3(40,6,115),Vector3(62.5,4.8,136)],
		["finish_straight",Vector3(-40,22,100),Vector3(50,1,130)],
		["flag_stand_rear",Vector3(78,12,145),Vector3(62.5,4,136)],
	]:
		camera.position = track.global_position+view[1]
		camera.look_at(track.global_position+view[2])
		for i in range(16):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/%s.png" % view[0])
	print("FLAG STAND CHECK PASSED: legacy grid slots hidden; stand aligned with finish stripe. Captures complete.")
	quit()
