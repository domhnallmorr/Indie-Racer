extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func place(car, distance: float, choice: float, speed: float) -> void:
	var driver = car.get_node("Driver")
	driver.mode = 2
	driver.index = 0
	for i in range(driver.race.size()):
		if driver.race_distances[i] <= distance:
			driver.index = i
	driver.racecraft.lane = choice
	driver.racecraft.target_lane = choice
	var point: Vector3 = driver.racecraft.path_point(driver,0,choice)
	var tangent: Vector3 = driver.racecraft.path_point(driver,2,choice)-point
	car.global_position = car.track.to_global(point+Vector3.UP*.1)
	car.rotation.y = atan2(-tangent.x,-tangent.z)
	var simulation = car.get("sim")
	if simulation != null:
		simulation.u = speed
		simulation.v = 0
		simulation.yaw_rate = 0
		simulation.gear = 4
	car.speed_mps = speed
	car.velocity = -car.global_basis.z*speed

func validate() -> void:
	Engine.physics_ticks_per_second = 480
	Engine.time_scale = 8
	var sides := [-1.0] if "--inside-only" in OS.get_cmdline_user_args() else [-1.0,1.0,0.0]
	for side in sides:
		var main = load("res://game/main/main.tscn").instantiate()
		main.roster_file = "res://content/rosters/icr2_test/manifest.json"
		root.add_child(main)
		var fast = main.ai_cars[1]
		var slow = main.ai_cars[0]
		var driver = fast.get_node("Driver")
		var leader = slow.get_node("Driver")
		if not driver.racecraft.enabled:
			failures.append("Corridor failed to load")
			break
		# Start an already selected attempt on each side, then let both decide.
		# Approach the bend so the current roster's speed difference cannot
		# complete the entire move on the preceding straight.
		place(fast,330,0,65)
		place(slow,395 if side > 0 else 375,0,60)
		if side < 0:
			# Exercise an established inside overlap at turn entry separately
			# from the autonomous pull-out and outside approach fixtures.
			place(fast,380,-1,65)
			place(slow,385,0,65)
		driver.racecraft.target_lane = side
		if side != 0:
			driver.racecraft.opponent = slow
			driver.racecraft.attempts = 1
		leader.ratings.clear()
		leader.cornering_utilisation = .82
		leader.cornering_base = .82
		var contact_ticks := 0
		var overlap_ticks := 0
		var corner_overlap_ticks := 0
		var minimum_clearance := INF
		var maximum_offset := 0.0
		for tick in range(7200):
			await physics_frame
			var fast_p: Vector2 = driver.racecraft.coordinates(driver,fast)
			var slow_p: Vector2 = driver.racecraft.coordinates(driver,slow)
			var separation: float = fposmod(slow_p.x-fast_p.x+driver.race_length_m*.5,driver.race_length_m)-driver.race_length_m*.5
			maximum_offset = maxf(maximum_offset,maxf(absf(fast_p.y),absf(slow_p.y)))
			if absf(separation) < 5:
				overlap_ticks += 1
				minimum_clearance = minf(minimum_clearance,absf(fast_p.y-slow_p.y))
				if absf(fast.track.to_local(fast.global_position).x) > 220:
					corner_overlap_ticks += 1
					if "--capture" in OS.get_cmdline_user_args():
						main.process_mode = Node.PROCESS_MODE_DISABLED
						var camera = main.get_node("InspectionCamera")
						camera.followed_ai = 0
						camera.follow_player = false
						camera.target = (fast.global_position+slow.global_position)*.5
						camera.distance = 25
						camera.pitch = .65
						camera.yaw = fast.rotation.y+.6
						camera._update_camera()
						camera.make_current()
						main.get_node("HUD").hide()
						await process_frame
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png("res://builds/racecraft_corner.png")
						print("RACECRAFT CAPTURE SAVED")
						main.free()
						quit()
						return
			for vehicle in [fast,slow]:
				for i in range(vehicle.get_slide_collision_count()):
					if vehicle.get_slide_collision(i).get_collider() in [fast,slow]:
						contact_ticks += 1
			if tick % 1800 == 1799:
				print("side=%+.0f t=%.0f gap=%.1f lane=%.2f/%.2f state=%s speed=%.1f/%.1f passes=%d attempts=%d" % [side,(tick+1)/60.0,separation,driver.racecraft.lane,leader.racecraft.lane,driver.racecraft.state,fast.speed_mps*3.6,slow.speed_mps*3.6,driver.racecraft.passes,driver.racecraft.attempts])
		print("RACECRAFT side=%+.0f passes=%d aborts=%d overlap=%d corner_overlap=%d contacts=%d clearance=%.2f max_offset=%.2f" % [side,driver.racecraft.passes,driver.racecraft.aborted,overlap_ticks,corner_overlap_ticks,contact_ticks,minimum_clearance,maximum_offset])
		if driver.racecraft.passes < 1:
			failures.append("No completed pass on side "+str(side))
		if overlap_ticks == 0:
			failures.append("No side-by-side running on side "+str(side))
		# The stronger outside-line tow can complete the pass before turn entry.
		if side <= 0 and corner_overlap_ticks == 0:
			failures.append("No side-by-side corner on side "+str(side))
		if contact_ticks > 0:
			failures.append("Vehicle contact on side "+str(side))
		if maximum_offset > 9:
			failures.append("Left safe track corridor on side "+str(side))
		main.free()
	for failure in failures:
		push_error(failure)
	print("RACECRAFT PASSED" if failures.is_empty() else "RACECRAFT FAILED")
	quit(0 if failures.is_empty() else 1)
