extends SceneTree
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.set_meta("roster_selection",{"track_id":"texas","session_mode":"private_testing","seed":123})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var car = main.player
	var monitor = main.get_node("PitMonitor")
	check(car.physics_ready and car.can_adjust_aero(),"Setup available in Private Testing pit stall")
	var initial_lock: float = car.sim.steering_lock_at_speed(100)
	car.get_node("Cockpit").activate()
	monitor.open()
	monitor._open_roll()
	monitor.roll.front.get_line_edit().text = "60"
	monitor.roll._apply()
	check(is_equal_approx(car.sim.p.front_roll_stiffness_fraction,.6),"Roll UI applies front balance")
	check(is_equal_approx(car.sim.steering_lock_at_speed(100),initial_lock),"Roll setup leaves steering mapping alone")
	car.sim.p.front_roll_stiffness_fraction = .5
	car.load_roll_setup(main.track_session_file)
	check(is_equal_approx(car.sim.p.front_roll_stiffness_fraction,.6),"Saved track balance reloads")
	check(car.save_roll_setup(NAN) == ERR_INVALID_PARAMETER and car.save_roll_setup(.2) == ERR_INVALID_PARAMETER,"Invalid setup rejected")
	var saved := ConfigFile.new()
	check(saved.load("user://mechanical_setups.cfg") == OK,"Mechanical setup saved")
	check(saved.has_section(main.track_session_file) and not saved.has_section("res://content/tracks/mile_oval/session.json"),"Setup is stored per track")
	# Malformed persisted values do not silently change the physical configuration.
	saved.set_value(main.track_session_file,"front_roll_stiffness_fraction","invalid")
	saved.save("user://mechanical_setups.cfg")
	car.load_roll_setup(main.track_session_file)
	check(is_equal_approx(car.sim.p.front_roll_stiffness_fraction,.6),"Malformed saved value ignored")
	check(car.save_roll_setup(.5) == OK,"Restore baseline setup through normal save path")
	monitor.roll.refresh()
	for i in range(3): await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/roll_setup.png")
	monitor.close()
	car.sim.u = 5
	check(car.save_roll_setup(.6) == ERR_UNAVAILABLE,"Moving car cannot change roll balance")
	car.sim.u = 0
	main.session.session_type = main.session.SessionType.RACE
	check(car.save_roll_setup(.6) == ERR_UNAVAILABLE,"Race setup changes are blocked")
	main.session.session_type = main.session.SessionType.PRIVATE_TESTING
	car.set_physics_process(false)
	# A controlled load/slide state makes every row and the post-peak warning
	# testable without relying on a live controller or a particular driving lap.
	car.sim.front_load = 7000
	car.sim.rear_load = 9000
	car.sim.lateral_contact_acceleration = 18
	car.sim._update_wheel_loads()
	for i in range(4): car.sim._wheel_force(i,0,.35 if i == 2 else .045,100000,1)
	var box = main.get_node("HUD/BlackBox")
	var event := InputEventKey.new()
	event.keycode = KEY_F5
	event.pressed = true
	box._unhandled_input(event)
	check(box.active_page == 4 and car.driving_enabled,"F5 shows loads without stopping driving")
	check(box.load_rows[0][1].text == "%.0f N" % car.sim.wheel_loads[0],"HUD displays model loads")
	check(box.load_rows[2][3].text == "SLIDING","HUD flags post-peak tyre even below 100 percent force")
	for i in range(3): await process_frame
	print("LOAD HUD rect=",box.get_global_rect()," viewport=",box.get_viewport_rect()," window=",root.size)
	check(box.get_global_rect().end.x <= box.get_viewport_rect().size.x+1,"Load display fits viewport width")
	check(box.roll_balance.get_global_rect().end.y < box.footer.get_global_rect().position.y,"Load rows fit above footer")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/tyre_loads.png")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("ROLL SETUP PASSED: pit UI, persistence, validation, restrictions, fixed steering, F5 loads and sliding state.")
	quit(0 if failures.is_empty() else 1)
