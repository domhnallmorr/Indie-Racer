extends SceneTree
## Recorded horizontal corner entry, with vertical motion left continuous.
## This reproduces chassis/road interference; it is not a driver/lap replay.
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
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/indy_travel_corner_entry.json"))
	var first: Array = fixture.rows[0]
	car.reset_dynamics()
	car.global_position = circuit.to_global(Vector3(first[1],first[2],first[3]))
	car.rotation.y = deg_to_rad(first[4])
	car.sim.gear = 0
	for frame in range(120):
		await physics_frame
		car.drive_step(1.0/60,0,1,0)
	var floor_frames := 0
	var peak_pitch := 0.0
	var peak_roll := 0.0
	var min_load := INF
	var max_gap := 0.0
	for row in fixture.rows:
		await physics_frame
		var at := circuit.to_global(Vector3(row[1],0,row[3]))
		car.global_position.x = at.x
		car.global_position.z = at.z
		car.rotation.y = deg_to_rad(row[4])
		car.sim.u = row[5]
		car.sim.v = row[6]
		car.sim.yaw_rate = deg_to_rad(row[7])
		car.sim.lateral_contact_acceleration = row[9]
		car.sim.load_transfer_acceleration = row[10]
		car.sim.front_omega = row[5]/car.sim.p.front_radius_m
		car.sim.rear_omega = row[5]/car.sim.p.rear_radius_m
		car.drive_step(1.0/60,0,0,row[8],true)
		if car.is_on_floor(): floor_frames += 1
		peak_pitch = maxf(peak_pitch,absf(rad_to_deg(car.sim.suspension.pitch)))
		peak_roll = maxf(peak_roll,absf(rad_to_deg(car.sim.suspension.roll)))
		min_load = minf(min_load,car.sim.front_load+car.sim.rear_load)
		for gap in car.sim.suspension.gaps: max_gap = maxf(max_gap,gap)
	print("CORNER SUPPORT floor_frames=",floor_frames," pitch_deg=",peak_pitch," roll_deg=",peak_roll," min_load_n=",min_load," max_gap_m=",max_gap)
	if floor_frames > 0: failures.append("Chassis must not ride the smooth bank during recorded entry")
	if peak_pitch > 3 or peak_roll > 5: failures.append("Corner entry body angles remain bounded")
	if min_load < 12000: failures.append("Corner support retains high-speed tyre loading")
	# Also integrate position and yaw freely using the recorded driver inputs,
	# initial wheel/engine state and recorded aero/gearing settings.
	car.reset_dynamics()
	car.global_position = circuit.to_global(Vector3(first[1],first[2],first[3]))
	car.rotation.y = deg_to_rad(first[4])
	for frame in range(120):
		await physics_frame
		car.drive_step(1.0/60,0,1,0)
	car.sim.u = first[5]
	car.sim.v = first[6]
	car.sim.yaw_rate = deg_to_rad(first[7])
	var initial: Dictionary = fixture.initial
	car.sim.gear = int(first[13])
	car.sim.automatic = false
	car.sim.engine_omega = initial.rpm*TAU/60
	car.sim.clutch = initial.clutch_engagement
	car.sim.throttle = first[11]
	car.sim.steer = deg_to_rad(initial.steer_deg)
	car.sim.front_left_omega = initial.front_left_omega_rad_s
	car.sim.front_right_omega = initial.front_right_omega_rad_s
	car.sim.rear_left_omega = initial.rear_left_omega_rad_s
	car.sim.rear_right_omega = initial.rear_right_omega_rad_s
	car.sim.front_omega = (car.sim.front_left_omega+car.sim.front_right_omega)*.5
	car.sim.rear_omega = (car.sim.rear_left_omega+car.sim.rear_right_omega)*.5
	car.player_state.fuel_gal = initial.fuel_gal
	car.sim.p.final_drive = initial.final_drive
	car.sim.p.front_roll_stiffness_fraction = initial.front_roll_stiffness_fraction
	car.sim.p.downforce_area_m2 = initial.downforce_area_m2
	car.sim.p.drag_area_m2 = initial.drag_area_m2
	car.sim.p.front_downforce_fraction = initial.front_aero_fraction
	for i in range(6): car.sim.p.forward_ratios[i] = initial["gear_ratio_%d" % (i+1)]
	floor_frames = 0
	peak_pitch = 0
	peak_roll = 0
	var lost_support := 0
	for row in fixture.rows:
		await physics_frame
		car.drive_step(1.0/60,row[11],row[12],row[8],true)
		if car.is_on_floor(): floor_frames += 1
		if not car.sim.suspension.has_support(): lost_support += 1
		peak_pitch = maxf(peak_pitch,absf(rad_to_deg(car.sim.suspension.pitch)))
		peak_roll = maxf(peak_roll,absf(rad_to_deg(car.sim.suspension.roll)))
	print("CORNER DRIVE floor_frames=",floor_frames," lost_support=",lost_support," pitch_deg=",peak_pitch," roll_deg=",peak_roll," speed_kph=",car.speed_mps*3.6)
	if floor_frames > 0 or lost_support > 0: failures.append("Unconstrained corner drive retains suspension support without chassis floor contact")
	if peak_pitch > 3 or peak_roll > 5: failures.append("Unconstrained corner drive body angles remain bounded")
	car.player_state.pit_stall_state = car.player_state.StallState.STOPPED
	car.sim.u = 0
	car.sim.v = 0
	car.save_suspension_enabled(true,false)
	if not car.get_node("CollisionShape3D").transform.is_equal_approx(car.suspension_collision_rest):
		failures.append("Roll/pitch comparison restores original collision shape transform")
	car.telemetry.stop()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("CORNER SUPPORT PASSED: continuous heave, bank clearance and tyre loads.")
	quit(0 if failures.is_empty() else 1)
