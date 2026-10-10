extends SceneTree
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.set_meta("roster_selection",{"track_id":"indianapolis","session_mode":"private_testing","seed":123})
	var main = load("res://game/main/main.tscn").instantiate()
	main.ai_enabled = false
	root.add_child(main)
	await process_frame
	var car = main.player
	check(car.physics_ready and car.can_adjust_aero(),"Indy private testing setup available")
	check(car.sim.suspension.enabled,"Indy prototype enabled by default")
	check(car.suspension_visual != null,"Separate chassis visual created")
	var monitor = main.get_node("PitMonitor")
	monitor.open()
	monitor._open_roll()
	check(monitor.roll.dynamic_body.visible and monitor.roll.dynamic_body.button_pressed,"Indy comparison checkbox available")
	monitor.roll.dynamic_body.button_pressed = false
	monitor.roll._apply()
	check(not car.sim.suspension.enabled,"UI disables prototype")
	car.load_suspension_setup(main.track_session_file)
	check(not car.sim.suspension.enabled,"Disabled choice persists")
	monitor.roll.dynamic_body.button_pressed = true
	monitor.roll._apply()
	check(car.sim.suspension.enabled,"UI re-enables prototype")
	monitor.close()
	car.set_physics_process(false)
	for i in range(25):
		await physics_frame
		car.velocity = Vector3.DOWN*3
		car._move_with_car_contacts(1.0/60)
		car._update_visual_grounding(1.0/60)
	var visual: Node3D = car.get_node("Visual")
	var wheels: Array[Node3D] = []
	var original: Array[Transform3D] = []
	for wheel_name in ["WheelFrontLeft","WheelFrontRight","WheelRearLeft","WheelRearRight"]:
		var wheel: Node3D = visual.find_child(wheel_name,true,false)
		check(wheel != null and wheel.get_parent() == visual,"Wheel stays in grounded visual frame")
		wheels.append(wheel)
		original.append(wheel.transform)
	for i in range(2000): car.sim.suspension.advance(.0005,4000,-3000,1,true)
	car._update_visual_grounding(1.0/60)
	check(not car.suspension_visual.basis.is_equal_approx(Basis.IDENTITY),"Chassis follows simulated roll/pitch")
	for i in range(4): check(wheels[i].transform.is_equal_approx(original[i]),"Chassis lean preserves wheel stance")
	var cockpit_expected: Transform3D = visual.transform*car.suspension_visual.transform*Transform3D(Basis.IDENTITY,visual.get_meta("cockpit_offset"))
	check(car.get_node("Cockpit").transform.is_equal_approx(cockpit_expected),"Cockpit follows chassis modes")
	car.telemetry.record(car,1.0/60,Vector3.ZERO,Vector3.UP,Vector3(0,0,9.81),1,true,Vector3.ZERO)
	car.telemetry.stop()
	var csv := FileAccess.open(car.telemetry.path,FileAccess.READ)
	var header := csv.get_csv_line()
	check("body_roll_deg" in header and "body_pitch_deg" in header and "dynamic_roll_pitch" in header,"Suspension telemetry columns")
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() > 1: check(row.size() == header.size(),"Telemetry row alignment")
	car.reset_dynamics()
	check(car.suspension_visual.transform.is_equal_approx(Transform3D.IDENTITY),"Reset clears chassis visual")
	car.load_suspension_setup("res://content/tracks/texas/session.json")
	check(not car.sim.suspension.enabled,"Other tracks retain prior physics")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("INDY SUSPENSION PASSED: track activation, pit comparison, persistence, chassis/wheel separation, cockpit, telemetry, reset.")
	quit(0 if failures.is_empty() else 1)
