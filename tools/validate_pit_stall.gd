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
	state._input(event)

func validate() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_file = "res://content/rosters/icr2_test/manifest.json"
	root.add_child(main)
	var car = main.player
	var state = car.player_state
	check(state.pit_stall_state == state.StallState.STOPPED and car.engine_rpm == 0,"Practice starts parked, engine off")
	check(is_equal_approx(state.selected_fuel_gal,35.0),"Full fuel load initially")
	car.drive_step(.016,1,0,1)
	check(car.engine_rpm == 0 and car.sim.throttle == 0 and absf(car.speed_mps) < .01,"Parked inputs cannot power car")
	var monitor = main.get_node("PitMonitor")
	check(monitor.available(),"Practice pit monitor available")
	key(monitor,KEY_ENTER)
	check(monitor.focused and not state.engine_running,"Enter opens monitor without departing")
	monitor._open_setup()
	check(monitor.setup_page.visible and car.can_adjust_aero(),"Setup accessible in parked practice")
	monitor._open_wings()
	check(monitor.wings_page.visible and not monitor.setup_page.visible,"Wings opens its editor")
	key(monitor,KEY_ESCAPE)
	check(monitor.setup_page.visible,"Escape from wings returns to setup submenu")
	monitor._open_fuel()
	check(monitor.fuel_page.visible,"Fuel Load opens its editor")
	monitor._fuel(-5.0)
	check(is_equal_approx(state.fuel_gal,30.0),"Monitor fuel selection updates car")
	key(monitor,KEY_ESCAPE)
	check(monitor.setup_page.visible,"Escape from fuel returns to setup submenu")
	key(monitor,KEY_ESCAPE)
	check(monitor.home.visible and monitor.focused,"Escape returns to monitor home")
	key(monitor,KEY_ESCAPE)
	check(not monitor.focused,"Escape returns to cockpit")
	var ui = main.get_node("HUD/RaceUI")
	check(not ui.pages.has("aero"),"Setup removed from F12")
	ui.open_page("session")
	key(monitor,KEY_ENTER)
	check(not monitor.focused and not state.engine_running,"Session panel blocks monitor input")
	ui.close_shell()
	monitor.open()
	monitor._depart()
	check(state.engine_running and car.engine_rpm > 0,"Leave starts engine")
	state._physics_process(1)
	check(state.pit_stall_state == state.StallState.RELEASING,"Release cannot immediately repark")
	car.global_position = state.stall_pose*Vector3(0,0,-5)
	state._physics_process(.1)
	check(state.pit_stall_state == state.StallState.NONE,"Clearing stall rearms detection")
	state.consume_distance(1609.344)
	check(state.fuel_gal < 30.0,"Driving consumes the selected load")
	var fuel_before_arrival: float = state.fuel_gal
	car.global_transform = state.stall_pose
	car.rotate_y(PI)
	state._physics_process(1)
	check(state.pit_stall_state == state.StallState.NONE,"Wrong heading rejected")
	car.global_transform = state.stall_pose
	car.speed_mps = 2
	state._physics_process(1)
	check(state.pit_stall_state == state.StallState.NONE,"Passing through rejected")
	check(is_equal_approx(state.fuel_gal,fuel_before_arrival),"Passing through does not refuel")
	car.speed_mps = 0
	state._physics_process(.2)
	check(state.pit_stall_state == state.StallState.NONE,"Arrival requires dwell")
	state._physics_process(.2)
	check(not state.engine_running and monitor.available(),"Return shuts down and restores monitor")
	check(is_equal_approx(state.fuel_gal,30.0) and is_equal_approx(state.selected_fuel_gal,30.0),"Return restores selected fuel without menu input")
	state.session.session_type = state.session.SessionType.QUALIFYING
	state.fuel_gal = 32.0
	state.park_in_stall()
	check(is_equal_approx(state.fuel_gal,30.0),"Qualifying arrival also restores load, including removing excess")
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
	check(not main.get_node("PitMonitor").available() and not main.player.can_adjust_aero(),"Race has no monitor or setup access")
	check(main.player_state.engine_running and main.player_state.pit_stall_state == 0,"Race starts running without stall restrictions")
	main.player_state.fuel_gal = 12.0
	main.player_state.park_in_stall()
	check(is_equal_approx(main.player_state.fuel_gal,12.0),"Race bypasses instant setup refuelling")
	main.free()
	print("PIT STALL PASSED" if failures.is_empty() else "PIT STALL FAILED: "+str(failures))
	quit(0 if failures.is_empty() else 1)
