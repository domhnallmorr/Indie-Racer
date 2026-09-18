extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("validate")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
func validate() -> void:
	Engine.physics_ticks_per_second = 600
	Engine.time_scale = 10
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_seed = 1234
	if "--bicycle" in OS.get_cmdline_user_args():
		main.roster_file = "res://content/rosters/default/manifest.json"
	root.add_child(main)
	main.set_process(false)
	var car = main.ai_cars[-1] if "--natural" in OS.get_cmdline_user_args() else main.ai_cars[0]
	var driver = car.get_node("Driver")
	for other in main.ai_cars:
		var d = other.get_node("Driver")
		check(d.stint_laps >= 6 and d.stint_laps <= 20,"Lap range")
		check(d.release_delay >= 4 and d.release_delay <= 120,"Initial departure range")
		check(other.get_collision_exceptions().has(main.player),"Parked AI ignores player")
		if other != car:
			d.set_physics_process(false)
	driver.release_delay = 0
	if "--natural" in OS.get_cmdline_user_args():
		driver.stint_laps = 6
	var phase := 0
	for tick in range(24000):
		await physics_frame
		if phase == 0 and driver.mode == driver.Mode.RACING:
			check(not car.get_collision_exceptions().has(main.player),"Exit restores player collision")
			# Accelerate the stint without bypassing the approach trigger or driving.
			if not "--natural" in OS.get_cmdline_user_args():
				driver.stint_start_laps = driver._timed_laps()-driver.stint_laps
			phase = 1
		if phase == 1 and driver.mode == driver.Mode.PIT_ENTRY:
			check(driver._timed_laps()-driver.stint_start_laps >= driver.stint_laps,"Stint respects completed lap target")
			check(car.get_collision_exceptions().has(main.player),"Inbound AI ignores player")
			phase = 2
		if phase == 2 and driver.mode == driver.Mode.WAITING:
			check(car.global_position.distance_to(driver.pit_box_pose.origin) < .05,"Returns to assigned box")
			check(car.speed_mps == 0,"Stops in box")
			check(driver.release_delay-driver.elapsed >= 240 and driver.release_delay-driver.elapsed <= 600,"Dwell range")
			check(driver.completed_stints == 1,"Completed stint counted")
			var parked: Vector3 = car.global_position
			for unused in range(120):
				await physics_frame
			check(car.global_position.distance_to(parked) < .1,"Remains parked during dwell")
			driver.release_delay = driver.elapsed
			phase = 3
		if phase == 3 and driver.mode == driver.Mode.RACING:
			check(not car.get_collision_exceptions().has(main.player),"Repeat exit restores collision")
			phase = 4
			break
		if tick % 3600 == 3599:
			print("PIT CYCLE phase=",phase," mode=",driver.mode," index=",driver.index," position=",car.global_position," speed=",car.speed_mps)
	check(phase == 4,"Full departure / return / dwell / repeat completes, phase="+str(phase))
	if phase == 4:
		main.session.advance(3600.0)
		driver.index = driver.pit_entry_index
		car.global_position = car.track.to_global(driver.race[driver.index])
		driver._update_practice_cycle()
		check(driver.mode == driver.Mode.PIT_ENTRY,"Session end calls circulating AI in")
		car.global_transform = driver.pit_box_pose
		car.reset_dynamics()
		driver._update_practice_cycle()
		driver.release_delay = driver.elapsed
		driver._physics_process(1.0/60.0)
		check(driver.mode == driver.Mode.WAITING,"No departures after session end")
	for failure in failures:
		push_error(failure)
	print("PIT CYCLE RESULT: ",failures)
	main.free()
	quit(0 if failures.is_empty() else 1)
