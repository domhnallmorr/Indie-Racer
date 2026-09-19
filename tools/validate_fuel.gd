extends SceneTree
## Player-only fuel regression: pit selection, mass change, consumption and range.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func key(state: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	state._unhandled_input(event)

func validate() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	main.ai_enabled = false
	root.add_child(main)
	var car = main.player
	var state = car.player_state
	check(is_equal_approx(state.fuel_gal,35.0),"Practice begins with a full 35-gallon load")
	key(state,KEY_LEFT)
	check(is_equal_approx(state.selected_fuel_gal,30.0) and is_equal_approx(state.fuel_gal,30.0),"Pit fuel row selects 5-gallon steps")
	var light_mass: float = car.parameters.values.mass_kg+state.fuel_mass_kg()
	key(state,KEY_RIGHT)
	var full_mass: float = car.parameters.values.mass_kg+state.fuel_mass_kg()
	check(full_mass > light_mass and full_mass > 800.0,"Fuel load adds physical mass")
	state.set_engine_running(true)
	state.consume_distance(state.fuel_reference_lap_m*60.0)
	check(state.fuel_gal < .001,"Full tank covers exactly 60 nominal laps")
	state.configure_fuel(car.parameters.values,3.0)
	state.consume_distance(state.fuel_reference_lap_m)
	check(is_equal_approx(state.fuel_gal,3.0-35.0/60.0),"Small tank keeps the same per-lap consumption")
	main.session.session_type = main.session.SessionType.RACE
	main.session.status = main.session.Status.RUNNING
	state.pit_stall_state = state.StallState.NONE
	car.global_transform = state.stall_pose
	car.reset_dynamics()
	state._physics_process(.36)
	check(state.pit_stall_state == state.StallState.SERVICING and not state.engine_running,"Player race stop starts refuelling")
	check(state.service_duration_seconds >= 10.0 and state.service_duration_seconds <= 13.0,"Player service duration is in range")
	var sampled_duration: float = state.service_duration_seconds
	state._physics_process(sampled_duration-.01)
	check(state.pit_stall_state == state.StallState.SERVICING and state.fuel_gal < 3.0,"Player held for sampled service time")
	state._physics_process(.01)
	check(state.pit_stall_state == state.StallState.RELEASING and state.engine_running and is_equal_approx(state.fuel_gal,3.0),"Player released full after service")
	state.start_refuelling(11.5)
	check(is_equal_approx(state.service_duration_seconds,11.5) and state.service_remaining == 11.5,"Scheduled AI service duration is retained")
	main.free()
	for failure in failures:
		push_error(failure)
	print("FUEL PASSED" if failures.is_empty() else "FUEL FAILED: "+str(failures))
	quit(0 if failures.is_empty() else 1)
