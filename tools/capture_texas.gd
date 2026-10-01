extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.set_meta("roster_selection",{"track_id":"texas","file":"res://content/rosters/irl_2001/manifest.json"})
	var main = load("res://game/main/main.tscn").instantiate()
	main.ai_enabled = false
	root.add_child(main)
	var camera: Camera3D = main.get_node("InspectionCamera")
	camera.near = 1
	main.get_node("HUD").hide()
	for canvas in main.player.find_children("*","CanvasLayer",true,false):
		canvas.hide()
	camera.follow_player = false
	camera.target = Vector3.ZERO
	camera.distance = 1100
	camera.yaw = .2
	camera.pitch = 1.2
	camera._update_camera()
	camera.make_current()
	for frame in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/texas_overview.png")
	camera.target = main.get_node("MileOval").bank_focus
	camera.distance = 80
	camera.yaw = -1.57
	camera.pitch = .3
	camera._update_camera()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/texas_banking.png")
	quit()
