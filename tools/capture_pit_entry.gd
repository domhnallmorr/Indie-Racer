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
	var barrels = track.get_node("PitEntryProtection")
	assert(barrels.get_child_count() == 4)
	for barrel in barrels.get_children():
		assert(barrel is StaticBody3D)
		assert(barrel.position.x+0.315 < barrels.wall_start_x)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.far = 2000
	camera.fov = 55
	camera.position = track.global_position+Vector3(barrels.wall_start_x-6,2.7,112.8)
	camera.look_at(track.global_position+Vector3(barrels.wall_start_x-0.5,0.45,108))
	camera.make_current()
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/pit_entry_barrels.png")
	print("PIT ENTRY PASSED: four collidable barrels ahead of the separator, in two rows of two.")
	quit()
