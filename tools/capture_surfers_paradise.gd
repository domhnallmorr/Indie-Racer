extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.set_meta("roster_selection",{"track_id":"surfers_paradise","session_mode":"private_testing","ai_telemetry":false})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	if "--unbatched" in OS.get_cmdline_user_args():
		main.visual_batches.set_enabled(false)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	var camera: Camera3D = main.get_node("InspectionCamera")
	main.get_node("HUD").hide()
	for canvas in main.player.find_children("*","CanvasLayer",true,false):
		canvas.hide()
	camera.follow_player = false
	camera.near = 5
	camera.far = 9000
	camera.target = Vector3.ZERO
	camera.distance = 1180
	camera.yaw = .10
	camera.pitch = 1.08
	camera._update_camera()
	camera.make_current()
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/surfers_overview.png")
	camera.near = .5
	camera.target = main.get_node("MileOval").bank_focus
	camera.distance = 75
	camera.yaw = 0
	camera.pitch = 1.2
	camera._update_camera()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/surfers_chicane.png")
	var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/surfers_paradise/geometry.json"))
	if not geometry.get("first_chicane",{}).is_empty():
		var detail: Dictionary = geometry.first_chicane
		var track: Node3D = main.get_node("MileOval")
		var saved_pose: Transform3D = main.player.global_transform
		main.player.driving_enabled = false
		var line: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/surfers_paradise/ai/race_line.json"))
		var at: Array = line.points[233]
		var next: Array = line.points[235]
		main.player.global_position = track.to_global(Vector3(at[0],.025,at[2]))
		main.player.look_at(track.to_global(Vector3(next[0],.025,next[2])))
		camera.set_process(false)
		camera.set_physics_process(false)
		camera.global_position = track.to_global(Vector3(detail.camera_position[0],detail.camera_position[1],detail.camera_position[2]))
		camera.look_at(track.to_global(Vector3(detail.camera_target[0],detail.camera_target[1],detail.camera_target[2])))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/surfers_t1_broadcast.png")
		main.player.global_transform = saved_pose
	if not geometry.get("backstraight_chicane",{}).is_empty():
		var detail: Dictionary = geometry.backstraight_chicane
		var track: Node3D = main.get_node("MileOval")
		camera.set_process(false)
		camera.set_physics_process(false)
		camera.global_position = track.to_global(Vector3(detail.camera_position[0],detail.camera_position[1],detail.camera_position[2]))
		camera.look_at(track.to_global(Vector3(detail.camera_target[0],detail.camera_target[1],detail.camera_target[2])))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/surfers_backstraight.png")
	camera.target = main.get_node("MileOval").pit_focus
	camera.distance = 130
	camera.yaw = 2.4
	camera.pitch = .55
	camera._update_camera()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/surfers_pits.png")
	quit()
