extends SceneTree
func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	Engine.physics_ticks_per_second = 480
	Engine.time_scale = 8
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_seed = 1234
	root.add_child(main)
	assert(main.ai_cars.size() == 15)
	var errors: Array[String] = []
	var joined := {}
	var contacts := 0
	var edge_ticks := 0
	var limiter_ticks := 0
	var maximum_offset := 0.0
	var peak_speed_kph := 0.0
	var passes := 0
	var boxes := {}
	for car in main.ai_cars:
		assert(car.get_node("Driver").profile_ready)
		assert(car.get_node("Driver").racecraft.enabled)
		assert(not boxes.has(car.player_state.assigned_pit_box_id))
		boxes[car.player_state.assigned_pit_box_id] = true
	for tick in range(18000):
		await physics_frame
		for car in main.ai_cars:
			var driver = car.get_node("Driver")
			if car.player_state.is_in_pit_speed_zone and car.speed_mps*3.6 > 80.1:
				limiter_ticks += 1
			if driver.mode == 2:
				peak_speed_kph = maxf(peak_speed_kph,car.speed_mps*3.6)
				if not joined.has(car.name):
					joined[car.name] = (tick+1)/60.0
				var offset: float = absf(driver.racecraft.coordinates(driver,car).y)
				maximum_offset = maxf(maximum_offset,offset)
				if offset > 9:
					edge_ticks += 1
			for c in range(car.get_slide_collision_count()):
				if car.get_slide_collision(c).get_collider() is CharacterBody3D:
					contacts += 1
		if tick % 3600 == 3599:
			print("ICR2 FIELD seconds=",(tick+1)/60," joined=",joined.size()," contacts=",contacts)
	var results: Array = []
	for entry in main.lap_timing.entries.slice(1):
		passes += entry.car.get_node("Driver").racecraft.passes
		results.append({"name":entry.name,"laps":entry.laps,"best_s":entry.best,"join_s":joined.get(entry.car.name,0)})
		if entry.laps < 4:
			errors.append("Insufficient circulation: "+entry.name)
	if joined.size() != 15 or contacts > 0 or edge_ticks > 0 or limiter_ticks > 0:
		errors.append("Field departure/contact/clearance/limiter failure")
	if peak_speed_kph > 322:
		errors.append("Excessive straight-line speed")
	var report := {"results":results,"contacts":contacts,"passes":passes,"peak_speed_kph":peak_speed_kph,"edge_ticks":edge_ticks,"limiter_violations":limiter_ticks,"max_road_offset_m":maximum_offset,"errors":errors}
	var file := FileAccess.open("res://builds/icr2_field.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify(report))
	main.free()
	quit(0 if errors.is_empty() else 1)
