extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.set_meta("roster_selection", {"session_mode": "qualifying", "seed": 42, "race_laps": 23, "max_fuel_capacity_gal": 3.0})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main.session.set_process(false)
	check(main.session.clock_text() == "10:00", "Qualifying lasts ten minutes")
	check(main.session.session_type == main.session.SessionType.QUALIFYING, "Qualifying type")
	check(main.player_state.pit_stall_state == main.player_state.StallState.STOPPED, "Player begins in stall")
	check(main.player_state.request_departure(), "Player can leave qualifying stall")
	main.player_state.park_in_stall()
	check(not main.player_state.engine_running, "Player can park again")
	for car in main.ai_cars:
		var driver = car.get_node("Driver")
		check(driver.practice_cycle and driver.release_delay >= 0 and driver.release_delay <= 420, "Practice AI schedule reused")
	# Deliberate times exercise ranking, ties, and drivers without a completed lap.
	main.lap_timing.entries[0].best = 20.0
	main.lap_timing.entries[1].best = 22.0
	main.lap_timing.entries[2].best = 21.0
	main.lap_timing.entries[3].best = 22.0
	var expected: Array = []
	for entry in main.lap_timing.standings():
		expected.append(main._car_id(entry.car))
	check(expected[0] == "player" and expected[1] == main._car_id(main.ai_cars[1]), "Fastest laps rank first")
	check(expected[2] == main._car_id(main.ai_cars[0]) and expected[3] == main._car_id(main.ai_cars[2]), "Equal laps retain entry order ahead of untimed cars")
	main.session.advance(599.0)
	check(main.session.clock_text() == "00:01", "Clock counts down")
	main.session.advance(1.0)
	check(main.session.status == main.session.Status.FINISHED, "Ends at zero")
	for frame in range(8):
		await process_frame
	var menu = current_scene
	check(menu.current_screen == menu.Screen.WEEKEND, "Returns to weekend")
	check(menu.laps_select.value == 23 and menu.fuel_select.value == 3, "Settings preserved")
	check(root.get_meta("roster_selection").qualifying_grid == expected, "Qualifying classification saved")
	check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(menu.get_node("Center/WeekendMenu/Panel").get_global_rect()), "Results menu fits screen")
	menu._on_race_pressed()
	for frame in range(5):
		await process_frame
	main = current_scene
	main.set_physics_process(false)
	for car in [main.player] + main.ai_cars:
		car.set_physics_process(false)
		if car.has_node("Driver"):
			car.get_node("Driver").set_physics_process(false)
	check(main.grid_ids == expected and main.player_grid_slot == 0, "Race uses qualifying grid including player pole")
	check(main.formation_leader == main.player, "Pole player leads formation")
	for entry in main.lap_timing.entries:
		check(entry.order == expected.find(main._car_id(entry.car)), "Initial race standings use grid")
		var slot: int = expected.find(main._car_id(entry.car))
		check(entry.car.global_position.distance_to(main.get_node("MileOval").to_global(main.track_data.grid_transform(slot).origin)) < 4, "Cars spawn in earned slots")
	main.green_previous_x = main.track_data.green_point.x - 1
	main.player.global_position = main.get_node("MileOval").to_global(Vector3(main.track_data.green_point.x + 1, 0, 125))
	main._physics_process(0)
	check(main.session.status == main.session.Status.RUNNING, "Player leader triggers green")
	for car in main.ai_cars:
		check(car.get_node("Driver").mode == 2, "Green releases AI")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("QUALIFYING CHECK PASSED: clock, pit controls, AI release schedule, classification, weekend return, settings, grid and player-led green.")
	quit(0 if failures.is_empty() else 1)
