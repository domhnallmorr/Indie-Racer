extends SceneTree
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_file = "res://content/rosters/icr2_test/manifest.json"
	root.add_child(main)
	for tick in range(5400):
		await physics_frame
		var car = main.ai_cars[1]
		var driver = car.get_node("Driver")
		var position: Vector3 = car.track.to_local(car.global_position)
		if driver.laps >= 1 and absf(position.x) > 295:
			main.process_mode = Node.PROCESS_MODE_DISABLED
			var camera = main.get_node("InspectionCamera")
			camera.followed_ai = 1
			camera.follow_player = false
			camera.target = car.global_position
			camera.distance = 18
			camera.pitch = .4
			camera.yaw = car.rotation.y+.65
			camera._update_camera()
			camera.make_current()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://builds/icr2_corner.png")
			print("ICR2 CAPTURE SAVED")
			main.free()
			quit()
			return
	push_error("ICR2 did not reach capture position")
	main.free()
	quit(1)
