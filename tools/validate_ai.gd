extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	# Preserve the game's 1/60-second physics step while accelerating the run.
	Engine.physics_ticks_per_second = 480
	Engine.time_scale = 8
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_file = "res://content/rosters/default/manifest.json"
	root.add_child(main)
	var seen_unlimited := [false,false]
	var seen_limiter := [false,false]
	var last_modes := [-1,-1]
	var maximum_road_offsets := [0.0,0.0]
	if main.ai_cars.size() != 2:
		push_error("Expected two AI cars")
		quit(1)
		return
	for car in main.ai_cars:
		assert(car.physics_ready and not car.human_controlled)
		assert(car.parameters.values == main.player.parameters.values, "AI and player must share vehicle parameters")
		assert(car.wheel_input == null, "AI must not read human controls")
		if "--capture" in OS.get_cmdline_user_args():
			var driver = car.get_node("Driver")
			if driver.diagnostic != null:
				driver.diagnostic.close()
			driver.diagnostic = FileAccess.open("res://ai_validation_"+str(car.name)+".csv",FileAccess.WRITE)
			if driver.diagnostic == null:
				push_error("Cannot write AI validation capture")
				quit(1)
				return
			driver.diagnostic.store_csv_line(driver.DIAGNOSTIC_HEADER.split(","))
	for step in range(10800):
		await physics_frame
		for i in range(2):
			var car = main.ai_cars[i]
			var driver = car.get_node("Driver")
			if driver.mode == driver.Mode.RACING and driver.racecraft.enabled:
				maximum_road_offsets[i] = maxf(maximum_road_offsets[i],absf(driver.racecraft.coordinates(driver,car).y))
			if driver.mode != last_modes[i]:
				print("%s mode=%s t=%.1f position=%s" % [car.name,driver.mode,driver.elapsed,car.position])
				last_modes[i] = driver.mode
			if car.player_state.is_in_pit_speed_zone:
				if car.speed_mps > 80.0/3.6+.01:
					failures.append("Limiter exceeded")
				if car.speed_mps > 15:
					seen_limiter[i] = true
			elif driver.mode == driver.Mode.PIT_EXIT and car.speed_mps > 80.0/3.6+1:
				seen_unlimited[i] = true
		if step % 1800 == 1799:
			for car in main.ai_cars:
				var driver = car.get_node("Driver")
				print("%s t=%.1f idx=%d speed=%.1f laps=%d pos=%s error=%.2f" % [car.name,driver.elapsed,driver.index,car.speed_mps*3.6,driver.laps,car.position,driver.max_line_error_m])
	for i in range(2):
		var car = main.ai_cars[i]
		var driver = car.get_node("Driver")
		if not seen_limiter[i] or not seen_unlimited[i]:
			failures.append(car.name+" did not exercise limited/unlimited exit")
		if driver.mode != driver.Mode.RACING or driver.laps < 2:
			failures.append(car.name+" did not complete repeated race laps")
		if maximum_road_offsets[i] > 9:
			failures.append(car.name+" exceeded physical road clearance")
	for entry in main.lap_timing.entries:
		if entry.car in main.ai_cars:
			print("%s timed laps=%d best=%.3f last=%.3f" % [entry.name,entry.laps,entry.best,entry.last])
			if entry.best <= 0 or entry.best > 24.0:
				failures.append(entry.name+" failed Mile Oval reference pace (24 s)")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("AI VALIDATION PASSED: two departures, limiter release, merges and repeated laps.")
	quit(0 if failures.is_empty() else 1)
