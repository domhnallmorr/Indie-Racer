extends SceneTree
## Fixed recorded controls; actual outer drive/collision cadence changes.
## 240 Hz is a convergence reference, not measured ground truth.
var results := []
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for hz in [60,120,240]:
		Engine.physics_ticks_per_second = hz
		# move_and_slide uses the engine's delta; it must match drive_step.
		Engine.time_scale = 1
		root.set_meta("roster_selection",{"track_id":"indianapolis","session_mode":"private_testing","seed":123})
		var main = load("res://game/main/main.tscn").instantiate()
		main.ai_enabled = false
		root.add_child(main)
		await physics_frame
		var car = main.player
		car.set_physics_process(false)
		car.player_state.pit_stall_state = car.player_state.StallState.NONE
		var circuit = main.get_node("MileOval")
		var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/indy_travel_corner_entry.json"))
		var first: Array = fixture.rows[0]
		car.reset_dynamics()
		car.global_position = circuit.to_global(Vector3(first[1],first[2],first[3]))
		car.rotation.y = deg_to_rad(first[4])
		car.sim.gear = 0
		for frame in range(2*hz):
			await physics_frame
			car.drive_step(1.0/hz,0,1,0)
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
		for key in ["front_left","front_right","rear_left","rear_right"]:
			car.sim.set(key+"_omega",initial[key+"_omega_rad_s"])
		car.sim.front_omega = (car.sim.front_left_omega+car.sim.front_right_omega)*.5
		car.sim.rear_omega = (car.sim.rear_left_omega+car.sim.rear_right_omega)*.5
		car.player_state.fuel_gal = initial.fuel_gal
		for key in ["final_drive","front_roll_stiffness_fraction","downforce_area_m2","drag_area_m2"]:
			car.sim.p[key] = initial[key]
		car.sim.p.front_downforce_fraction = initial.front_aero_fraction
		for i in range(6): car.sim.p.forward_ratios[i] = initial["gear_ratio_%d" % (i+1)]
		var metrics := {"hz":hz,"duration_s":fixture.rows.size()/60.0,"lost_support_s":0.0,"chassis_contact_s":0.0,"peak_roll_deg":0.0,"peak_pitch_deg":0.0,"peak_wheel_load_n":0.0,"min_total_load_n":INF,"samples":[]}
		# Each recorded 60 Hz control sample is held for the same 1/60 s.
		for row in fixture.rows:
			for sub in range(hz/60):
				await physics_frame
				car.drive_step(1.0/hz,row[11],row[12],row[8],true)
				observe(car,metrics,1.0/hz)
			metrics.samples.append(sample(car))
		metrics.final = sample(car)
		results.append(metrics)
		# Prescribed path isolates banking/support from accumulating steering error.
		var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/indianapolis/ai/reference_paths.json"))
		var start: Array = reference.reference_path[140]
		car.reset_dynamics()
		car.global_position = circuit.to_global(Vector3(start[0],start[1]+.02,start[2]))
		var next: Array = reference.reference_path[141]
		car.rotation.y = atan2(-(next[0]-start[0]),-(next[2]-start[2]))
		car.sim.gear = 0
		for frame in range(2*hz):
			await physics_frame
			car.drive_step(1.0/hz,0,1,0)
		var offset: float = car.global_position.y-circuit.to_global(Vector3(start[0],start[1],start[2])).y
		var previous_heading: float = car.rotation.y
		var bank := {"hz":hz,"duration_s":340.0/60,"lost_support_s":0.0,"chassis_contact_s":0.0,"peak_roll_deg":0.0,"peak_pitch_deg":0.0,"peak_wheel_load_n":0.0,"min_total_load_n":INF,"samples":[]}
		for frame in range(roundi(bank.duration_s*hz)):
			await physics_frame
			var progress: float = 140.0+frame*95.0/(2*hz)
			var index := int(progress)
			var a: Array = reference.reference_path[index]
			var b: Array = reference.reference_path[index+1]
			var target: Vector3 = circuit.to_global(Vector3(a[0],a[1],a[2]).lerp(Vector3(b[0],b[1],b[2]),progress-index))
			var heading := atan2(-(b[0]-a[0]),-(b[2]-a[2]))
			car.global_position = Vector3(target.x,target.y+offset,target.z)
			car.rotation.y = heading
			car.sim.u = 95
			car.sim.v = 0
			car.sim.yaw_rate = wrapf(heading-previous_heading,-PI,PI)*hz
			car.sim.front_omega = 95/car.sim.p.front_radius_m
			car.sim.rear_omega = 95/car.sim.p.rear_radius_m
			car.drive_step(1.0/hz,0,0,.02,true)
			observe(car,bank,1.0/hz)
			var query := PhysicsRayQueryParameters3D.create(car.global_position+Vector3.UP*.6,car.global_position-Vector3.UP*2,1)
			query.exclude = [car.get_rid()]
			var hit := root.world_3d.direct_space_state.intersect_ray(query)
			if not hit.is_empty(): offset = car.global_position.y-hit.position.y
			previous_heading = heading
		bank.final = sample(car)
		metrics.banking = bank
		for scenario in [metrics,bank]:
			if scenario.lost_support_s > 0 or scenario.chassis_contact_s > 0:
				failures.append("%d Hz replay lost suspension support or hit the chassis" % hz)
		car.telemetry.stop()
		main.free()
		await physics_frame
	DirAccess.make_dir_recursive_absolute("res://builds")
	var file := FileAccess.open("res://builds/indy_physics_rates.json",FileAccess.WRITE)
	if file == null:
		push_error("Cannot save rate comparison")
		quit(1)
		return
	file.store_string(JSON.stringify(results,"  "))
	file.close()
	for result in results:
		var compact: Dictionary = result.duplicate(true)
		compact.erase("samples")
		compact.banking.erase("samples")
		print("RATE COMPARISON ",JSON.stringify(compact))
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func sample(car) -> Dictionary:
	return {"position":[car.global_position.x,car.global_position.y,car.global_position.z],"yaw_deg":rad_to_deg(car.rotation.y),"speed_mps":car.sim.u,"roll_deg":rad_to_deg(car.sim.suspension.roll),"pitch_deg":rad_to_deg(car.sim.suspension.pitch),"wheel_loads_n":Array(car.sim.wheel_loads)}

func observe(car, metrics: Dictionary, dt: float) -> void:
	if not car.sim.suspension.has_support(): metrics.lost_support_s += dt
	if car.is_on_floor(): metrics.chassis_contact_s += dt
	metrics.peak_roll_deg = maxf(metrics.peak_roll_deg,absf(rad_to_deg(car.sim.suspension.roll)))
	metrics.peak_pitch_deg = maxf(metrics.peak_pitch_deg,absf(rad_to_deg(car.sim.suspension.pitch)))
	metrics.min_total_load_n = minf(metrics.min_total_load_n,car.sim.front_load+car.sim.rear_load)
	for load_n in car.sim.wheel_loads:
		metrics.peak_wheel_load_n = maxf(metrics.peak_wheel_load_n,load_n)
		if not is_finite(load_n) and "Nonfinite load" not in failures: failures.append("Nonfinite load")
	if not car.global_position.is_finite() and "Nonfinite position" not in failures: failures.append("Nonfinite position")
