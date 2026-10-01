extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func validate() -> void:
	root.set_meta("roster_selection", {"session_mode":"race", "race_laps":100, "file":"res://content/rosters/icr2_test/manifest.json", "seed":1234})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	var state = main.player_state
	var session = main.session
	var lap: float = state.TYRE_LIFE_M/100.0
	check(state.tyre_condition == 1.0 and state.tyre_wear_rate == 1.0,"Player starts fresh with constant wear")
	state.consume_distance(lap)
	check(state.tyre_condition == 1.0,"Formation does not wear tyres")
	session.status = session.Status.RUNNING
	state.engine_running = true
	state.is_in_pit_lane = false
	state.pit_stall_state = state.StallState.NONE
	state.consume_distance(lap*10)
	check(is_equal_approx(state.tyre_condition,.9),"Player wears one percentage point per nominal mile lap")
	var condition: float = state.tyre_condition
	state.consume_tyre_distance(0)
	state.consume_tyre_distance(-lap)
	state.consume_tyre_distance(INF)
	state.is_in_pit_lane = true
	state.consume_tyre_distance(lap)
	state.is_in_pit_lane = false
	session.status = session.Status.FINISHED
	state.consume_tyre_distance(lap)
	session.status = session.Status.RUNNING
	session.session_type = session.SessionType.PRACTICE
	state.consume_tyre_distance(lap)
	check(state.tyre_grip_multiplier() == 1.0 and state.tyre_pace_penalty_s() == 0.0,"Practice handling unaffected")
	session.session_type = session.SessionType.QUALIFYING
	state.consume_tyre_distance(lap)
	check(is_equal_approx(state.tyre_condition,condition),"Invalid distance, pits, finished sessions, practice and qualifying do not wear tyres")
	session.session_type = session.SessionType.RACE
	state.consume_tyre_distance(lap*200)
	check(state.tyre_condition == 0.0 and is_equal_approx(state.tyre_grip_multiplier(),.92),"Wear and player grip have safe floors")
	state.start_refuelling(10.0)
	state._physics_process(9.0)
	check(state.tyre_condition == 0.0,"Tyres are not renewed before service completes")
	state._physics_process(1.0)
	check(state.tyre_condition == 1.0 and state.pit_stall_state == state.StallState.RELEASING,"Player service restores tyres before release")
	var rates := []
	for car in main.ai_cars:
		var ai = car.player_state
		var driver = car.get_node("Driver")
		check(ai.tyre_wear_rate >= .85 and ai.tyre_wear_rate <= 1.15,"AI wear stays in range")
		rates.append(ai.tyre_wear_rate)
		var seed_value: int = driver.ratings.get("variation_seed",0)
		var rate: float = ai.tyre_wear_rate
		ai.configure_tyre_wear(seed_value)
		check(is_equal_approx(ai.tyre_wear_rate,rate),"AI rate is reproducible")
		ai.engine_running = true
		ai.is_in_pit_lane = false
		ai.pit_stall_state = ai.StallState.NONE
		var fresh_target: float = driver.target_lap_s()
		ai.consume_tyre_distance(lap*60)
		check(is_equal_approx(ai.tyre_condition,1.0-.6*rate),"AI retains its sampled wear rate over a stint")
		check(is_equal_approx(driver.target_lap_s()-fresh_target,1.2*rate),"AI target pace declines with tyre wear independently of fuel")
		ai.start_refuelling(10.0)
		driver.service_started = driver.elapsed
		driver.service_duration_seconds = 10.0
		driver.service_start_fuel = ai.fuel_gal
		driver.elapsed += 9.0
		check(driver._update_race_service() and ai.tyre_condition < 1.0,"AI holds worn tyres during service")
		driver.elapsed += 1.0
		check(not driver._update_race_service() and ai.tyre_condition == 1.0,"AI service restores tyres")
		check(is_equal_approx(ai.tyre_wear_rate,rate),"New tyres retain the car's long-run setup")
	check(rates.size() > 1 and not is_equal_approx(rates[0],rates[1]),"AI cars have different long-run setups")
	main.free()
	for failure in failures:
		push_error(failure)
	print("TYRE WEAR PASSED" if failures.is_empty() else "TYRE WEAR FAILED: "+str(failures))
	quit(0 if failures.is_empty() else 1)
