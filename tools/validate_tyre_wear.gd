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
	var player_rate: float = state.tyre_wear_rate
	check(state.tyre_condition == 1.0 and player_rate >= .85 and player_rate <= 1.15,"Player starts fresh with configured variation")
	state.configure_tyre_wear(main.active_seed ^ int("player".hash()))
	check(is_equal_approx(state.tyre_wear_rate,player_rate),"Player variation is repeatable")
	state.consume_distance(lap)
	check(state.tyre_condition == 1.0,"Formation does not wear tyres")
	session.status = session.Status.RUNNING
	state.engine_running = true
	state.is_in_pit_lane = false
	state.pit_stall_state = state.StallState.NONE
	state.consume_distance(lap*10)
	check(is_equal_approx(state.tyre_condition,1.0-.1*player_rate),"Player wear uses sampled multiplier")
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
	check(is_equal_approx(state.tyre_condition,condition),"Invalid distance, pits and finished sessions do not wear tyres")
	session.session_type = session.SessionType.PRACTICE
	state.consume_tyre_distance(lap)
	check(is_equal_approx(state.tyre_condition,condition-.01*player_rate),"Practice consumes tyres at the race wear rate")
	check(state.tyre_grip_multiplier() < 1.0 and state.tyre_pace_penalty_s() > 0.0,"Practice wear affects handling and AI pace")
	condition = state.tyre_condition
	var panel = main.get_node("HUD/BlackBox")
	var key := InputEventKey.new()
	key.keycode = KEY_F4
	key.pressed = true
	panel.show()
	panel._unhandled_input(key)
	check(panel.active_page == 3 and panel.pages[3].visible,"F4 opens tyre page")
	check(absf(panel.tyre_bar.value-condition*100.0) <= panel.tyre_bar.step and panel.tyre_bar.visible,"Tyre bar shows remaining practice condition within display precision")
	check(not panel.fuel_values.has("Tyres"),"Fuel page no longer contains tyre indicator")
	state.park_in_stall()
	panel.refresh()
	check(state.tyre_condition == 1.0 and panel.tyre_bar.value == 100.0,"Practice pit arrival restores fresh tyres and display")
	state.request_departure()
	state.pit_stall_state = state.StallState.NONE
	condition = state.tyre_condition
	session.session_type = session.SessionType.QUALIFYING
	state.consume_tyre_distance(lap)
	check(is_equal_approx(state.tyre_condition,condition),"Qualifying does not wear tyres")
	check(state.tyre_grip_multiplier() == 1.0 and state.tyre_pace_penalty_s() == 0.0,"Qualifying handling unaffected")
	session.session_type = session.SessionType.RACE
	state.consume_tyre_distance(lap*200)
	check(state.tyre_condition == 0.0 and is_equal_approx(state.tyre_grip_multiplier(),.92),"Wear and player grip have safe floors")
	state.start_refuelling(10.0)
	state._physics_process(9.0)
	check(state.tyre_condition == 0.0,"Tyres are not renewed before service completes")
	state._physics_process(1.0)
	check(state.tyre_condition == 1.0 and state.pit_stall_state == state.StallState.RELEASING,"Player service restores tyres before release")
	check(is_equal_approx(state.tyre_wear_rate,player_rate),"Player retains variation through pit stops")
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
	var config := ConfigFile.new()
	var test_path := "res://tmp/tyre_wear_test.cfg"
	DirAccess.make_dir_recursive_absolute("res://tmp")
	config.set_value("variation","enabled",false)
	config.set_value("variation","min_multiplier",0.4)
	config.set_value("variation","max_multiplier",0.6)
	check(config.save(test_path) == OK,"Write isolated debug configuration")
	for car in [main.player]+main.ai_cars:
		car.player_state.configure_tyre_wear(42,test_path)
		check(car.player_state.tyre_wear_rate == 1.0,"Disabled variation resets every car to baseline")
	config.set_value("variation","enabled",true)
	config.save(test_path)
	for seed_value in range(20):
		state.configure_tyre_wear(seed_value,test_path)
		check(state.tyre_wear_rate >= .4 and state.tyre_wear_rate <= .6,"Custom bounds are respected")
	config.set_value("variation","max_multiplier",0.4)
	config.save(test_path)
	state.configure_tyre_wear(42,test_path)
	check(is_equal_approx(state.tyre_wear_rate,.4),"Equal bounds give a fixed multiplier")
	config.set_value("variation","min_multiplier",-1.0)
	config.save(test_path)
	state.configure_tyre_wear(42,test_path)
	check(state.tyre_wear_rate == 1.0,"Invalid bounds fall back to baseline")
	DirAccess.remove_absolute(test_path)
	main.free()
	root.set_meta("roster_selection", {"session_mode":"practice", "file":"res://content/rosters/icr2_test/manifest.json", "seed":1234})
	var practice = load("res://game/main/main.tscn").instantiate()
	root.add_child(practice)
	check(is_equal_approx(practice.player_state.tyre_wear_rate,player_rate),"Practice initializes the same player variation for the same seed")
	for i in range(practice.ai_cars.size()):
		check(is_equal_approx(practice.ai_cars[i].player_state.tyre_wear_rate,rates[i]),"Practice initializes the same AI variation for the same seed")
	practice.free()
	for failure in failures:
		push_error(failure)
	print("TYRE WEAR PASSED" if failures.is_empty() else "TYRE WEAR FAILED: "+str(failures))
	quit(0 if failures.is_empty() else 1)
