extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4
	root.set_meta("roster_selection",{"track_id":"indianapolis","session_mode":"private_testing","seed":123})
	var main = load("res://game/main/main.tscn").instantiate()
	main.ai_enabled = false
	root.add_child(main)
	await process_frame
	var car = main.player
	car.set_physics_process(false)
	car.player_state.pit_stall_state = car.player_state.StallState.NONE
	var circuit: Node3D = main.get_node("MileOval")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/indy_travel_spin.json"))
	var first: Array = fixture.rows[0]
	car.reset_dynamics()
	car.global_position = circuit.to_global(Vector3(first[1],first[2],first[3]))
	car.rotation.y = deg_to_rad(first[4])
	car.sim.gear = 0
	for i in range(120):
		await physics_frame
		car.drive_step(1.0/60,0,1,0)
	var peak_pitch := 0.0
	var peak_compression := 0.0
	var peak_stop := 0.0
	var peak_bank := 0.0
	var peak_old_bank := 0.0
	for row in fixture.rows:
		await physics_frame
		var at := circuit.to_global(Vector3(row[1],0,row[3]))
		car.global_position.x = at.x
		car.global_position.z = at.z
		car.rotation.y = deg_to_rad(row[4])
		car.sim.u = row[5]
		car.sim.v = row[6]
		car.sim.yaw_rate = deg_to_rad(row[7])
		car.sim.lateral_contact_acceleration = row[8]
		car.sim.load_transfer_acceleration = row[9]
		car.sim.front_omega = row[5]/car.sim.p.front_radius_m
		car.sim.rear_omega = row[5]/car.sim.p.rear_radius_m
		car.drive_step(1.0/60,0,0,0)
		peak_pitch = maxf(peak_pitch,absf(rad_to_deg(car.sim.suspension.pitch)))
		for compression in car.sim.suspension.compression: peak_compression = maxf(peak_compression,compression)
		for stop in car.sim.suspension.bump_stop_loads: peak_stop = maxf(peak_stop,stop)
		peak_bank = maxf(peak_bank,absf(car.sim.banking_load_n))
		peak_old_bank = maxf(peak_old_bank,absf(car.sim.vehicle_mass_kg*car.sim.yaw_rate*Vector2(car.sim.u,car.sim.v).dot(car.sim.turn_normal_factors)))
	print("SPIN pitch_deg=",peak_pitch," compression_m=",peak_compression," stop_n=",peak_stop," bank_n=",peak_bank," old_yaw_bank_n=",peak_old_bank)
	if peak_pitch > 1: failures.append("Recorded spin pitch remains small with stiff travel suspension")
	if peak_compression > .055 or peak_stop > 1: failures.append("Spin must not consume full bump travel on smooth banking")
	if peak_bank > peak_old_bank*.5: failures.append("Body rotation must not inflate bank support like trajectory curvature")
	car.telemetry.stop()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("SPIN PASSED: curvature support, bounded pitch and no bump-stop excursion.")
	quit(0 if failures.is_empty() else 1)
