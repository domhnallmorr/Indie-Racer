extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func key(state: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	state._unhandled_input(event)

func validate() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_file = "res://content/rosters/icr2_test/manifest.json"
	root.add_child(main)
	var car = main.player
	var state = car.player_state
	check(state.pit_stall_state == state.StallState.STOPPED and car.engine_rpm == 0,"Practice starts parked, engine off")
	check(state.pit_menu_selection == 1,"Fuel selected initially")
	car.drive_step(.016,1,0,1)
	check(car.engine_rpm == 0 and car.sim.throttle == 0 and absf(car.speed_mps) < .01,"Parked inputs cannot power car")
	key(state,KEY_ENTER)
	check(not state.engine_running,"Fuel placeholder cannot start engine")
	key(state,KEY_UP)
	key(state,KEY_ENTER)
	check(state.pit_menu_selection == 0 and not state.engine_running,"Tyres placeholder")
	key(state,KEY_DOWN)
	key(state,KEY_DOWN)
	var ui = main.get_node("HUD/RaceUI")
	ui.open_page("session")
	key(state,KEY_ENTER)
	check(not state.engine_running,"Panel prevents departure input")
	ui.close_shell()
	key(state,KEY_ENTER)
	check(state.engine_running and car.engine_rpm > 0,"Leave starts engine")
	state._physics_process(1)
	check(state.pit_stall_state == state.StallState.RELEASING,"Release cannot immediately repark")
	car.global_position = state.stall_pose*Vector3(0,0,-5)
	state._physics_process(.1)
	check(state.pit_stall_state == state.StallState.NONE,"Clearing stall rearms detection")
	car.global_transform = state.stall_pose
	car.rotate_y(PI)
	state._physics_process(1)
	check(state.pit_stall_state == state.StallState.NONE,"Wrong heading rejected")
	car.global_transform = state.stall_pose
	car.speed_mps = 2
	state._physics_process(1)
	check(state.pit_stall_state == state.StallState.NONE,"Passing through rejected")
	car.speed_mps = 0
	state._physics_process(.2)
	check(state.pit_stall_state == state.StallState.NONE,"Arrival requires dwell")
	state._physics_process(.2)
	check(not state.engine_running and state.pit_menu_selection == 1,"Return shuts down and resets menu")
	for ai in main.ai_cars:
		check(not ai.player_state.engine_running,"AI starts with engine off")
		var driver = ai.get_node("Driver")
		driver.release_delay = 0
		driver.rivals.clear()
		driver._physics_process(.016)
		check(ai.player_state.engine_running,"AI scheduled release starts engine")
	main.session.advance(3600)
	check(not state.request_departure(),"No departure after expiry")
	main.free()
	root.set_meta("roster_selection",{"session_mode":"race"})
	main = load("res://game/main/main.tscn").instantiate()
	main.ai_enabled = false
	root.add_child(main)
	check(main.player_state.engine_running and main.player_state.pit_stall_state == 0,"Race starts running without stall restrictions")
	main.free()
	print("PIT STALL PASSED" if failures.is_empty() else "PIT STALL FAILED: "+str(failures))
	quit(0 if failures.is_empty() else 1)
