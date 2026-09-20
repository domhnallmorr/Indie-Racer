extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	Engine.physics_ticks_per_second = 600
	Engine.time_scale = 10.0
	var roster := "icr2_test" if "--small" in OS.get_cmdline_user_args() else "icr2_full"
	var mixed := "--mixed" in OS.get_cmdline_user_args()
	root.set_meta("roster_selection",{"session_mode":"race","race_laps":80,"file":"res://content/rosters/"+roster+"/manifest.json","seed":1234})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.player.global_transform = main.get_node("MileOval").global_transform*main.track_data.pit_box_transform()
	main.player.driving_enabled = false
	main.player.update_zone_state()
	var control = main.race_control
	check(not control.call_caution(),"Cannot call yellow during formation")
	for car in main.ai_cars:
		car.get_node("Driver").race_plan.failure_progress = INF
	if "--fast-start" in OS.get_cmdline_user_args():
		main.session.show_green()
		main.pace_car.phase = main.pace_car.Phase.PARKED
		main.pace_car.global_transform = main.get_node("MileOval").global_transform*main.track_data.pace_car_box
		main.pace_car.speed_mps = 0.0
		for i in range(main.ai_cars.size()):
			var car = main.ai_cars[i]
			var driver = car.get_node("Driver")
			var at: float = 900-i*35
			var p: Vector3 = control.circuit.sample_baked(at)
			var ahead: Vector3 = control.circuit.sample_baked(at+2)
			car.global_transform = car.track.global_transform*Transform3D(Basis.looking_at((ahead-p).normalized()),p+Vector3.UP*.025)
			car.speed_mps = 65.0
			driver.start_formation(0,80)
			driver.release_to_race()
			main.lap_timing.entries[i+1].previous = car.track.to_local(car.global_position)
			main.lap_timing.entries[i+1].laps = 3 if i == 0 else 2
			car.update_zone_state()
	for tick in range(60*140):
		await physics_frame
		if main.session.status == main.session.Status.RUNNING and main.lap_timing.entries[1].laps >= 2:
			break
	check(main.session.status == main.session.Status.RUNNING,"Formation reaches green")
	# Force a real retirement, with the survivors making strategic fuel stops.
	var expected_stops := []
	for i in range(main.ai_cars.size()):
		var car = main.ai_cars[i]
		car.player_state.fuel_gal = 35.0 if mixed and i%2 == 1 else 18.0
		if car.player_state.fuel_gal < 20.0:
			expected_stops.append(car)
	var retired = main.ai_cars[-1].get_node("Driver")
	retired.race_plan.fail(retired)
	check(control.active() and control.caution_count == 1,"Mechanical failure calls yellow")
	check(not retired.car in control.queue,"Retired car excluded from queue")
	check(main.session.status == main.session.Status.RUNNING,"Caution leaves timing and service running")
	check(not control.should_pit(main.ai_cars[0].get_node("Driver")),"Normal stops prohibited while closed")
	var saved_fuel: float = main.player_state.fuel_gal
	main.player_state.fuel_burn_factor = control.FUEL_FACTOR
	main.player_state.consume_distance(main.player_state.fuel_reference_lap_m)
	check(is_equal_approx(saved_fuel-main.player_state.fuel_gal,main.player_state.fuel_per_lap_gal*.45),"Yellow saves fuel per lap")
	main.player_state.fuel_gal = saved_fuel
	var before_clock: float = main.lap_timing.clock
	var before_laps: int = main.lap_timing.entries[1].laps
	var phases := {}
	var last_phase := -1
	var restarted := false
	var minimum_fuel := 100.0
	for tick in range(60*900):
		await physics_frame
		phases[control.phase] = true
		if control.phase != last_phase or tick%3600 == 0:
			last_phase = control.phase
			print("CAUTION t=",tick/60.0," phase=",control.phase," pace=",main.pace_car.phase," picked=",main.pace_car.caution_picked_up," queue=",control.queue.size()," gathered=",control._gathered())
			if tick%3600 == 0:
				for car in control.queue:
					print("  ",car.name," p=",control.progress[car]," speed=",car.speed_mps*3.6," target=",control.target_speed(car)*3.6)
		for car in main.ai_cars:
			minimum_fuel = minf(minimum_fuel,car.player_state.fuel_gal)
		if control.phase == control.Phase.GREEN:
			restarted = true
			break
	check(restarted,"Caution completes a restart with live traffic")
	check(phases.has(control.Phase.OPEN) and phases.has(control.Phase.ONE_TO_GREEN) and phases.has(control.Phase.RESTART),"All caution phases exercised")
	check(main.lap_timing.clock > before_clock and main.lap_timing.entries[1].laps > before_laps,"Yellow counts laps without resetting timing")
	check(minimum_fuel > 0,"No surviving AI runs out of fuel")
	for car in main.ai_cars:
		if car == retired.car:
			continue
		if car in expected_stops:
			check(car.get_node("Driver").completed_fuel_stops >= 1,"Strategic caution stop: "+str(car.name))
		elif mixed:
			check(car.get_node("Driver").completed_fuel_stops == 0,"Full tank stays out: "+str(car.name))
		check(car.get_node("Driver").mode == 2,"Survivor resumes racing: "+str(car.name))
		check(car.player_state.fuel_burn_factor == 1.0,"Green restores fuel rate")
	# Redeploy the same pace car, then finish under yellow without resetting laps.
	if restarted:
		for tick in range(60*20):
			await physics_frame
		check(control.call_caution("Second caution"),"Repeated deployment accepted")
		for tick in range(60*180):
			await physics_frame
			if control.phase == control.Phase.OPEN:
				break
		check(control.phase == control.Phase.OPEN,"Second pickup and field bunching complete")
		main.lap_timing.entries[1].laps = main.session.race_laps
		main._physics_process(0.0)
		check(main.session.status == main.session.Status.FINISHED and not control.active(),"Race may finish under yellow")
	print("CAUTIONS ","PASSED" if failures.is_empty() else failures)
	main.free()
	quit(0 if failures.is_empty() else 1)
