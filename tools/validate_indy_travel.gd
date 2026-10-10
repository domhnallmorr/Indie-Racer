extends SceneTree
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok and message not in failures: failures.append(message)

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
	check(car._suspension_owns_support() and car.floor_snap_length == 0,"Suspension owns support without floor snap")
	var circuit: Node3D = main.get_node("MileOval")
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/indianapolis/ai/reference_paths.json"))
	for index in [0,250,400,552]:
		var row: Array = reference.reference_path[index]
		var next: Array = reference.reference_path[index+1]
		var at := Vector3(row[0],row[1],row[2])
		var direction := Vector3(next[0]-row[0],0,next[2]-row[2]).normalized()
		car.reset_dynamics()
		car.global_transform = circuit.global_transform*Transform3D(Basis(Vector3.UP,atan2(-direction.x,-direction.z)),at+Vector3.UP*.02)
		car.sim.gear = 0
		for frame in range(150):
			await physics_frame
			car.drive_step(1.0/60,0,1,0)
			for load_n in car.sim.wheel_loads: check(is_finite(load_n) and load_n >= 0,"Finite real-track wheel loads")
		check(car.sim.suspension.travel_active() and car.sim.suspension.has_support(),"Real track suspension support")
		check(absf(car.sim.suspension.heave_velocity_mps) < .02,"Parked heave settles on flat/banked road")
		var total: float = car.sim.front_load+car.sim.rear_load
		var expected: float = car.sim.vehicle_mass_kg*9.81*car.suspension_normal.y
		check(absf(total-expected) < 120,"Parked road-normal weight balance")
		var gap := 0.0
		for wheel in car.suspension_wheels:
			var bottom: Vector3 = wheel.to_global(Vector3(0,-.327,0))
			var query := PhysicsRayQueryParameters3D.create(bottom+Vector3.UP*.5,bottom-Vector3.UP*.5,1)
			query.exclude = [car.get_rid()]
			var hit := root.world_3d.direct_space_state.intersect_ray(query)
			check(not hit.is_empty(),"Wheel has real road surface")
			if not hit.is_empty(): gap = maxf(gap,absf((bottom-hit.position).dot(hit.normal)))
		print("INDY TRAVEL parked sample=",index," normal=",car.suspension_normal," gap=",gap," load=",total," expected=",expected)
		check(gap < .035,"Suspension wheels stay grounded on banking")
	# Prescribed reference-path traversal isolates vertical support from driver
	# line choice. This is a 95 m/s support/transition test, not a lap-time test.
	car.player_state.pit_stall_state = car.player_state.StallState.NONE
	car.reset_dynamics()
	var start: Array = reference.reference_path[140]
	car.global_position = circuit.to_global(Vector3(start[0],start[1]+.02,start[2]))
	var height_offset := .02
	var last_heading := 0.0
	var max_roll := 0.0
	var max_heave_speed := 0.0
	var max_stop_load := 0.0
	var lost_support := 0
	for frame in range(340):
		await physics_frame
		var progress := 140.0+frame*95.0/120.0
		var index := int(progress)
		var fraction := progress-index
		var row: Array = reference.reference_path[index]
		var next: Array = reference.reference_path[index+1]
		var at := Vector3(row[0],row[1],row[2]).lerp(Vector3(next[0],next[1],next[2]),fraction)
		var dir := Vector3(next[0]-row[0],0,next[2]-row[2]).normalized()
		var heading := atan2(-dir.x,-dir.z)
		var target := circuit.to_global(at)
		car.global_position.x = target.x
		car.global_position.z = target.z
		car.global_position.y = target.y+height_offset
		car.rotation.y = heading
		car.sim.u = 95
		car.sim.v = 0
		car.sim.yaw_rate = wrapf(heading-last_heading,-PI,PI)*60 if frame > 0 else 0
		car.sim.front_omega = 95/car.sim.p.front_radius_m
		car.sim.rear_omega = 95/car.sim.p.rear_radius_m
		car.drive_step(1.0/60,0,0,.02,true)
		max_roll = maxf(max_roll,absf(car.sim.suspension.roll))
		max_heave_speed = maxf(max_heave_speed,absf(car.sim.suspension.heave_velocity_mps))
		for stop in car.sim.suspension.bump_stop_loads: max_stop_load = maxf(max_stop_load,stop)
		if not car.sim.suspension.has_support(): lost_support += 1
		check(is_finite(car.global_position.y) and absf(car.sim.suspension.heave_velocity_mps) < 5,"Finite high-speed transition support")
		var center_query := PhysicsRayQueryParameters3D.create(car.global_position+Vector3.UP*.6,car.global_position-Vector3.UP*2,1)
		center_query.exclude = [car.get_rid()]
		var center_hit := root.world_3d.direct_space_state.intersect_ray(center_query)
		if not center_hit.is_empty(): height_offset = car.global_position.y-center_hit.position.y
		last_heading = heading
	print("INDY TRAVEL transitions roll_deg=",rad_to_deg(max_roll)," heave_mps=",max_heave_speed," stop_n=",max_stop_load," no_support_frames=",lost_support)
	check(lost_support == 0,"Smooth Indy banking transitions retain support")
	check(max_roll < deg_to_rad(8),"Bank transitions avoid excessive body roll")
	car.sim.u = 0
	car.sim.v = 0
	car.sim.yaw_rate = 0
	# A car deliberately placed beyond droop must fall instead of snapping down.
	car.global_position += Vector3.UP*1.0
	car.reset_dynamics()
	var before: float = car.global_position.y
	await physics_frame
	car.drive_step(1.0/60,0,0,0)
	check(car.sim.front_load == 0 and car.sim.rear_load == 0,"Airborne tyre loads zero")
	check(car.sim.suspension.heave_velocity_mps < 0,"Airborne body falls")
	check(before-car.global_position.y < .02,"No downward floor snap")
	check(absf(car.velocity.x) < .03 and absf(car.velocity.z) < .03,"Banked freefall remains vertical in world axes")
	for frame in range(150):
		await physics_frame
		car.drive_step(1.0/60,0,1,0)
	check(car.sim.suspension.has_support() and absf(car.sim.suspension.heave_velocity_mps) < .05,"Landing re-establishes suspension support")
	# Save only while parked; comparison changes retain the existing profile.
	car.player_state.pit_stall_state = car.player_state.StallState.STOPPED
	car.sim.u = 0
	car.sim.v = 0
	check(car.save_suspension_enabled(true,false) == OK,"Travel comparison can be disabled in pit")
	check(not car._suspension_owns_support() and is_equal_approx(car.floor_snap_length,.8),"Roll/pitch-only comparison restores previous support")
	check(car.save_suspension_enabled(true,true) == OK,"Restore travel test")
	car.telemetry.record(car,1.0/60,Vector3.ZERO,Vector3.UP,Vector3(0,0,9.81),1,true,Vector3.ZERO)
	car.telemetry.stop()
	var csv := FileAccess.open(car.telemetry.path,FileAccess.READ)
	var header := csv.get_csv_line()
	check("fl_compression_m" in header and "rr_bump_stop_n" in header,"Travel telemetry available")
	while not csv.eof_reached():
		var values := csv.get_csv_line()
		if values.size() > 1: check(values.size() == header.size(),"Travel CSV row alignment")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("INDY TRAVEL PASSED: real road support, parked banking, wheel stance, freefall, landing, comparison and telemetry.")
	quit(0 if failures.is_empty() else 1)
