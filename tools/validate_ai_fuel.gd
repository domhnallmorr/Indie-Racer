extends SceneTree
## ICR2 fuel pace regression using the player-derived linear calibration.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func validate() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_file = "res://content/rosters/icr2_test/manifest.json"
	root.add_child(main)
	var car = main.ai_cars[0]
	var driver = car.get_node("Driver")
	var state = car.player_state
	check(is_equal_approx(state.fuel_gal,35.0),"AI begins with a full tank")
	var full_target: float = driver.target_lap_s()
	var full_scale: float = driver.effective_pace_scale()
	state.fuel_gal = 0.0
	var empty_target: float = driver.target_lap_s()
	var empty_scale: float = driver.effective_pace_scale()
	check(is_equal_approx(full_target-empty_target,35.0*driver.FUEL_PACE_PENALTY_S_PER_GAL),"Full-tank pace penalty is linear")
	check(empty_scale > full_scale,"AI pace increases as fuel burns")
	state.fuel_gal = state.fuel_capacity_gal
	state.set_engine_running(true)
	state.consume_distance(state.fuel_reference_lap_m)
	check(is_equal_approx(state.fuel_gal,state.fuel_capacity_gal*(1.0-1.0/state.fuel_range_laps)) ,"AI consumes one nominal lap of fuel by distance")
	main.free()
	for failure in failures:
		push_error(failure)
	print("AI FUEL PASSED" if failures.is_empty() else "AI FUEL FAILED: "+str(failures))
	quit(0 if failures.is_empty() else 1)
