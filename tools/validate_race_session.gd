extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func validate() -> void:
	Engine.physics_ticks_per_second = 120
	Engine.time_scale = 8.0
	root.set_meta("roster_selection",{"file":"res://content/rosters/icr2_full/manifest.json","seed":42,"session_mode":"race"})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	var session = main.session
	check(session.session_type == session.SessionType.RACE,"Race session selected")
	check(session.status == session.Status.FORMATION,"Race begins under formation")
	check(session.race_laps == 10,"Race is ten laps")
	check(main.ai_cars.size() == 15,"Full field loaded")
	check(main.ai_cars[0].get_meta("driver_name") == "Harper Fox" and main.ai_cars[5].get_meta("driver_name") == "Casey Grant" and main.ai_cars[-1].get_meta("driver_name") == "Alex Shaw","Race uses the roster's fixed mixed grid")
	var cars: Array = main.ai_cars.duplicate()
	cars.append(main.player)
	for i in range(cars.size()):
		var expected: Transform3D = main.track_data.grid_transform(i)
		var actual: Transform3D = main.get_node("MileOval").global_transform.affine_inverse()*cars[i].global_transform
		check(actual.origin.distance_to(expected.origin) < .01,"Grid slot %d position" % i)
	if main.ai_cars.size() >= 2:
		check(main.ai_cars[0].get_node("Driver").mode == 3,"AI uses formation mode")
		check(is_equal_approx(main.ai_cars[0].get_node("Driver").formation_speed_kph,80.0),"AI formation speed")
		check(main.ai_cars[0].global_position.distance_to(main.player.global_position) > 4.9,"Two-wide lane spacing")
		for frame in range(1800):
			await physics_frame
			if session.status == session.Status.RUNNING:
				break
		if session.status != session.Status.RUNNING:
			for vehicle in main.ai_cars:
				var driver = vehicle.get_node("Driver")
				print("FORMATION DIAGNOSTIC ",vehicle.name," pos=",main.get_node("MileOval").to_local(vehicle.global_position)," speed=",vehicle.speed_mps*3.6," mode=",driver.mode," index=",driver.index," error=",driver.current_line_error)
		check(session.status == session.Status.RUNNING,"AI completes formation lap and receives Turn-four green")
		check(main.ai_cars[0].get_node("Driver").mode == 2,"Green releases AI to race")
		check(main.player.driving_enabled,"Player remains fully controlled")
	var timing = main.lap_timing
	timing.entries[1].laps = 10
	main._physics_process(0.0)
	check(session.status == session.Status.FINISHED,"First finisher ends race")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("RACE SESSION CHECK PASSED: grid, formation, green, player control and finish.")
	quit(0 if failures.is_empty() else 1)
