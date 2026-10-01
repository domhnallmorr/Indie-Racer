extends SceneTree
## Render five follow-camera frames of the seeded pack, 30 seconds after green.
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	Engine.physics_ticks_per_second = 60
	root.set_meta("roster_selection",{"track_id":"texas","file":"res://content/rosters/irl_2001/manifest.json","seed":42,"session_mode":"race","race_laps":30})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.player.global_transform = main.player.track.global_transform*main.track_data.pit_box_transform()
	main.player.reset_dynamics()
	for car in main.ai_cars:
		car.get_node("Driver").race_plan.failure_progress = INF
	var camera = main.get_node("InspectionCamera")
	camera.follow_player = false
	camera.tv_mode = false
	camera.distance = 35
	camera.pitch = .7
	camera.make_current()
	main.get_node("HUD").hide()
	for canvas in main.player.find_children("*","CanvasLayer",true,false):
		canvas.hide()
	var car = main.get_node("AI_Dare")
	DirAccess.make_dir_recursive_absolute("res://builds/texas_behavior/visual")
	var green := -1
	for tick in range(9000):
		await physics_frame
		camera.target = car.global_position
		camera.yaw = car.rotation.y+.3
		camera._update_camera()
		if main.session.status != main.session.Status.RUNNING:
			continue
		if green < 0:
			green = tick
		if tick-green >= 1800 and (tick-green-1800)%15 == 0:
			await RenderingServer.frame_post_draw
			var frame := (tick-green-1800)/15
			root.get_texture().get_image().save_png("res://builds/texas_behavior/visual/pack_%02d.png" % frame)
			print("TEXAS PACK CAPTURE ",frame)
			if frame >= 4:
				main.free()
				quit()
				return
	main.free()
	quit(1)
