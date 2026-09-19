extends SceneTree
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if "--live" in OS.get_cmdline_user_args():
		await run_live()
		return
	root.set_meta("roster_selection",{"session_mode":"race","race_laps":60,"file":"res://content/rosters/icr2_full/manifest.json","seed":1234})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.lap_timing.set_physics_process(false)
	for car in main.ai_cars:
		car.get_node("Driver").set_physics_process(false)
	var formation_driver = main.ai_cars[0].get_node("Driver")
	formation_driver.race_plan.failure_progress = 0.0
	check(not formation_driver.race_plan.update(formation_driver,1.0/60),"No failure during formation")
	main.session.show_green()
	var plans := {}
	var sampled_failures := 0
	# Independent draws should approach 20%, with stable results for identical seeds.
	var driver = main.ai_cars[0].get_node("Driver")
	for seed_value in range(1000):
		driver.car.player_state.configure_fuel(driver.car.parameters.values)
		var plan = load("res://game/race/ai_race_plan.gd").new()
		plan.configure(driver,seed_value)
		var range_laps: float = driver.car.player_state.fuel_capacity_gal/driver.car.player_state.fuel_per_lap_gal
		check(is_equal_approx(range_laps,60+plan.extra_range_laps),"Strategy has real extra fuel range")
		plans[plan.extra_range_laps] = true
		if is_finite(plan.failure_progress):
			sampled_failures += 1
			check(plan.failure_progress >= 3 and plan.failure_progress <= 57,"Failure is inside race")
		driver.car.player_state.configure_fuel(driver.car.parameters.values)
		var repeat = load("res://game/race/ai_race_plan.gd").new()
		repeat.configure(driver,seed_value)
		check(repeat.extra_range_laps == plan.extra_range_laps and repeat.failure_progress == plan.failure_progress,"Seed is repeatable")
	check(plans.size() == 3 and sampled_failures > 150 and sampled_failures < 250,"Strategy mix and 20% failures")
	var entry: Dictionary = main.lap_timing.entries[1]
	entry.laps = 4
	entry.armed = true
	entry.expected = 2
	var frozen_position: Vector3 = entry.previous
	var car = driver.car
	car.speed_mps = 65.0
	driver.race_plan.failure_progress = 4.0
	driver._physics_process(1.0/60)
	check(driver.race_plan.retired,"Scheduled failure triggers")
	check(car.collision_layer == 0 and car.collision_mask == 0 and car.get_meta("pit_ghost"),"Failure disables collisions and traffic obstruction")
	check(not car.player_state.engine_running and driver.race_plan.smoke.emitting,"Engine off and smoke emitted")
	check(entry.get("retired",false) and entry.retirement_reason == "Engine failure","Classification records DNF")
	for tick in range(900):
		driver._physics_process(1.0/60)
		if car.speed_mps == 0:
			break
	check(car.speed_mps == 0,"Failed car stops")
	var at := fposmod(driver.race_plan.distance,driver.race_length_m)
	var inner: Vector3 = driver._sample_path(driver.racecraft.inner,driver.race_distances,at)
	var stopped: Vector3 = car.track.to_local(car.global_position)
	check(Vector2(stopped.x-inner.x,stopped.z-inner.z).length() > 2.5,"Stopped left of inner racing corridor")
	var parked: Vector3 = car.global_position
	for tick in range(14*60):
		driver._physics_process(1.0/60)
	check(car.global_position.is_equal_approx(parked) and not driver.race_plan.recovered,"Remains at roadside for first 14 seconds")
	# Recovery continues after the chequered flag too.
	main.session.finish_race()
	for tick in range(65):
		driver._physics_process(1.0/60)
	check(driver.race_plan.recovered and car.global_position.is_equal_approx(driver.pit_box_pose.origin),"Recovers to assigned box after 15 seconds")
	check(not driver.race_plan.smoke.emitting,"Recovery stops new smoke")
	main.lap_timing.sample(entry,Vector3.ZERO,0,100)
	check(entry.laps == 4 and entry.previous == frozen_position,"Retirement freezes timing through recovery teleport")
	main.session.status = main.session.Status.RUNNING
	for tick in range(120):
		driver._physics_process(1.0/60)
	check(car.global_position.is_equal_approx(driver.pit_box_pose.origin) and not car.player_state.engine_running,"Retired car never rejoins")
	var slow_driver = main.ai_cars[1].get_node("Driver")
	slow_driver.car.speed_mps = 1.0
	slow_driver.race_plan.fail(slow_driver)
	var before: Vector3 = slow_driver.car.global_position
	slow_driver._physics_process(1.0/60)
	check(Vector2(before.x-slow_driver.car.global_position.x,before.z-slow_driver.car.global_position.z).length() < .2,"Low-speed failure begins a gradual pull-over")
	for tick in range(3*60):
		slow_driver._physics_process(1.0/60)
	check(slow_driver.car.speed_mps == 0 and slow_driver.race_plan.stopped_time < .1,"Slow car completes pull-over before roadside dwell")
	check(slow_driver.car.global_position.distance_to(before) > 2.0,"Low-speed failure reaches shoulder")
	print("RACE EVENTS: failure draws=",sampled_failures,"/1000; ","PASSED" if failures.is_empty() else failures)
	main.free()
	quit(0 if failures.is_empty() else 1)

func run_live() -> void:
	Engine.physics_ticks_per_second = 600
	Engine.time_scale = 10
	root.set_meta("roster_selection",{"session_mode":"race","race_laps":30,"max_fuel_capacity_gal":8.0,"file":"res://content/rosters/icr2_full/manifest.json","seed":1234})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.player.global_transform = main.get_node("MileOval").global_transform*main.track_data.pit_box_transform()
	main.player.driving_enabled = false
	var retired_count := 0
	for tick in range(90000):
		await physics_frame
		if tick%7200 == 0:
			print("LONG RACE t=",tick/60," leader laps=",main.lap_timing.standings()[0].laps)
		if main.session.status == main.session.Status.FINISHED:
			break
	check(main.session.status == main.session.Status.FINISHED,"Thirty-lap full-field race finishes")
	for entry in main.lap_timing.entries.slice(1):
		var driver = entry.car.get_node("Driver")
		if driver.race_plan.retired:
			retired_count += 1
			check(entry.get("retired",false),"Retired AI classified OUT")
		else:
			check(driver.completed_fuel_stops >= 1,"Surviving AI completes fuel stops")
		check(entry.car.track.to_local(entry.car.global_position).y > -2,"Car remains above track")
		print(entry.name," laps=",entry.laps," stops=",driver.completed_fuel_stops," extra_range=",driver.race_plan.extra_range_laps," retired=",driver.race_plan.retired)
	check(retired_count > 0,"Seeded full field includes retirement events")
	print("LONG RACE ","PASSED" if failures.is_empty() else failures)
	main.free()
	quit(0 if failures.is_empty() else 1)
