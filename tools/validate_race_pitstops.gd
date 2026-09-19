extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Engine.physics_ticks_per_second = 600
	Engine.time_scale = 10
	var roster := "icr2_full" if "--full-field" in OS.get_cmdline_user_args() else "icr2_test"
	var capacity := 3.0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fuel="):
			capacity = float(argument.trim_prefix("--fuel="))
	root.set_meta("roster_selection",{"session_mode":"race","race_laps":10,"max_fuel_capacity_gal":capacity,"file":"res://content/rosters/%s/manifest.json" % roster,"seed":1234})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.player.global_transform = main.get_node("MileOval").global_transform*main.track_data.pit_box_transform()
	main.player.driving_enabled = false
	# Isolate pit operations from overtaking/formation traffic deadlocks.
	if not "--traffic" in OS.get_cmdline_user_args():
		for car in main.ai_cars:
			car.get_node("Driver").rivals.clear()
			car.get_node("Driver").racecraft.enabled = false
	var began := {}
	var durations := []
	var min_fuel := 35.0
	var below_track := {}
	for car in main.ai_cars:
		# This check isolates refuelling; retirement lifecycle has its own test.
		car.get_node("Driver").race_plan.failure_progress = INF
		assert(is_equal_approx(car.player_state.fuel_capacity_gal,capacity))
		var extra: int = car.get_node("Driver").race_plan.extra_range_laps
		assert(is_equal_approx(capacity/car.player_state.fuel_per_lap_gal,capacity/(35.0/60.0)+extra))
	for tick in range(36000):
		await physics_frame
		if tick%3600 == 3599:
			for entry in main.lap_timing.entries.slice(1):
				var d = entry.car.get_node("Driver")
				print("t=",tick/60," ",entry.name," laps=",entry.laps," mode=",d.mode," fuel=",entry.car.player_state.fuel_gal," stops=",d.completed_fuel_stops," position=",entry.car.position," speed=",entry.car.speed_mps)
		for car in main.ai_cars:
			var d = car.get_node("Driver")
			if car.track.to_local(car.global_position).y < -2.0:
				below_track[car.name] = true
			min_fuel = minf(min_fuel,car.player_state.fuel_gal)
			if d.service_started >= 0 and not began.has(car.name):
				began[car.name] = {"started": d.elapsed, "sampled": d.service_duration_seconds}
			if began.has(car.name) and d.service_started < 0:
				durations.append({"actual": d.elapsed-began[car.name].started, "sampled": began[car.name].sampled})
				began.erase(car.name)
				assert(car.player_state.fuel_gal > capacity-.01,"Refill completed")
			if car.player_state.is_in_pit_speed_zone:
				assert(car.speed_mps*3.6 <= 80.1,"Pit limiter")
		if main.session.status == main.session.Status.FINISHED:
			break
	if main.session.status != main.session.Status.FINISHED:
		push_error("Ten-lap race did not finish")
		quit(1)
		return
	assert(durations.size() >= main.ai_cars.size(),"Field refuels")
	assert(min_fuel > 0.0,"No car runs dry before its stall")
	for duration in durations:
		assert(duration.sampled >= 10.0 and duration.sampled <= 13.0,"Service duration stays in range")
		assert(absf(duration.actual-duration.sampled) < .05,"Service lasts its sampled duration")
	for entry in main.lap_timing.entries.slice(1):
		assert(entry.car.get_node("Driver").completed_fuel_stops >= 1,"Every AI refuels")
		print(entry.name," laps=",entry.laps," stops=",entry.car.get_node("Driver").completed_fuel_stops," fuel=",entry.car.player_state.fuel_gal)
	print("FUEL CYCLE PASSED: service durations=",durations," minimum fuel=",min_fuel)
	if not below_track.is_empty():
		push_error("Race movement regression: cars below track: "+str(below_track.keys()))
	main.free()
	quit(0 if below_track.is_empty() else 1)
