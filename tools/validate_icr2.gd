extends SceneTree
## Real 60 Hz steps, physical pit departures and ordered timing gates.
func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	Engine.physics_ticks_per_second = 480
	Engine.time_scale = 8
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_file = "res://content/rosters/icr2_test/manifest.json"
	main.roster_seed = 1234
	root.add_child(main)
	if main.ai_cars.size() != 2:
		push_error("Expected two ICR2 cars")
		quit(1)
		return
	var errors: Array[String] = []
	var join_times := [0.0,0.0]
	var maximum_errors := [0.0,0.0]
	var road_offsets := [0.0,0.0]
	var contact_ticks := 0
	var limiter_ticks := [0,0]
	var join_speeds := [0.0,0.0]
	var pit_line_errors := [0.0,0.0]
	var backstraight_speeds := [0.0,0.0]
	var backstraight_ticks := [0,0]
	for car in main.ai_cars:
		var driver = car.get_node("Driver")
		if not driver.profile_ready:
			push_error(driver.profile_error)
			quit(1)
			return
		assert(driver.racecraft.enabled)
		assert(car.get_script().resource_path.ends_with("icr2_car.gd"))
		driver.diagnostic = FileAccess.open("res://builds/icr2_"+str(car.name)+".csv",FileAccess.WRITE)
		driver.diagnostic.store_line("time_s,mode,index,x_m,y_m,z_m,speed_kph,profile_kph,target_kph,line_error_m,reason,racecraft,lane,target_lane,opponent,passes")
	for tick in range(10800):
		await physics_frame
		for i in range(2):
			var car = main.ai_cars[i]
			var driver = car.get_node("Driver")
			if driver.mode == driver.Mode.PIT_EXIT:
				pit_line_errors[i] = maxf(pit_line_errors[i],driver.current_line_error)
				var position: Vector3 = car.track.to_local(car.global_position)
				if position.z < -100 and position.x > 60 and position.x < 180:
					backstraight_speeds[i] += car.speed_mps*3.6
					backstraight_ticks[i] += 1
			if car.player_state.is_in_pit_speed_zone:
				limiter_ticks[i] += 1
				if car.speed_mps*3.6 > 80.1:
					errors.append("Pit limiter exceeded")
			if driver.mode == driver.Mode.RACING:
				if join_times[i] == 0:
					join_times[i] = (tick+1)/60.0
					join_speeds[i] = car.speed_mps*3.6
				maximum_errors[i] = maxf(maximum_errors[i],driver.current_line_error)
				road_offsets[i] = maxf(road_offsets[i],absf(driver.racecraft.coordinates(driver,car).y))
			for c in range(car.get_slide_collision_count()):
				if car.get_slide_collision(c).get_collider() is CharacterBody3D:
					contact_ticks += 1
		if tick % 1800 == 1799:
			print("ICR2 seconds=",(tick+1)/60," laps=",main.lap_timing.entries[1].laps,",",main.lap_timing.entries[2].laps)
	var results: Array = []
	for i in range(2):
		var entry: Dictionary = main.lap_timing.entries[i+1]
		var backstraight_mean: float = backstraight_speeds[i]/maxi(1,backstraight_ticks[i])
		if join_speeds[i] < 250 or backstraight_mean < 180 or pit_line_errors[i] > 2:
			errors.append("Pit-out pace/tracking failed: "+entry.name)
		results.append({"name":entry.name,"laps":entry.laps,"best_s":entry.best,"last_s":entry.last,"join_s":join_times[i],"max_line_error_m":maximum_errors[i],"max_road_offset_m":road_offsets[i]})
		results[-1].merge_speed_kph = join_speeds[i]
		results[-1].pit_backstraight_mean_kph = backstraight_mean
		results[-1].max_pit_line_error_m = pit_line_errors[i]
		var pace_target: float = main.ai_cars[i].get_meta("roster_entry").icr2_lap_s
		if entry.laps < 4 or absf(entry.best-pace_target) > .2 or maximum_errors[i] > 2.0 or road_offsets[i] > 9 or join_times[i] == 0 or limiter_ticks[i] == 0:
			errors.append("Circulation failed: "+entry.name)
	if main.lap_timing.entries[2].best >= main.lap_timing.entries[1].best:
		errors.append("Fastest car should be quicker")
	if contact_ticks > 0:
		errors.append("Vehicle contacts: "+str(contact_ticks))
	var report := {"results":results,"contacts":contact_ticks,"errors":errors}
	var file := FileAccess.open("res://builds/icr2_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify(report))
	print("ICR2 PASSED" if errors.is_empty() else "ICR2 FAILED")
	main.free()
	quit(0 if errors.is_empty() else 1)
