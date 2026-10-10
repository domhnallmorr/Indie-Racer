extends "res://tools/fixtures/rear_wheel_cases.gd"
## Run with isolated APPDATA. Includes physics, live F10 and CSV verification.
var settings := Vector3(.30,.10,20)

func make_sim(_width: float, _fine := false):
	var sim = fine_model.new() if refine or _fine else Model.new()
	sim.configure(parameters.duplicate(true))
	sim.direct_steering = true
	assert(sim.set_rear_differential(settings.x,settings.y,settings.z))
	return sim

func seeded(speed: float):
	var sim = make_sim(2)
	sim.u = speed
	sim.gear = 0
	sim.front_omega = speed/parameters.front_radius_m
	sim.rear_omega = speed/parameters.rear_radius_m
	return sim

func mechanics() -> void:
	var sim = seeded(25)
	for torque in [400.0,-400.0]:
		for rotation in [60.0,-60.0]:
			for difference in [20.0,-20.0,.0001]:
				sim.rear_left_omega = rotation-difference*.5
				sim.rear_right_omega = rotation+difference*.5
				sim.rear_omega = rotation
				sim.rear_coupling_dissipation_j = 0
				var before_energy: float = parameters.rear_axle_inertia_kgm2*.25*(sim.rear_left_omega**2+sim.rear_right_omega**2)
				sim._couple_rear_wheels(.001,torque)
				var after_energy: float = parameters.rear_axle_inertia_kgm2*.25*(sim.rear_left_omega**2+sim.rear_right_omega**2)
				var drive: bool = torque*rotation > 0
				check(sim.rear_diff_drive_phase == drive,"Drive/coast follows power in forward and reverse")
				check(absf(sim.rear_diff_capacity_nm-(80 if drive else 40)) < .00001,"Correct drive/coast capacity")
				check(absf(sim.rear_omega-rotation) < .000001,"Coupling preserves carrier speed")
				check(absf(sim.rear_coupling_torque_nm) <= sim.rear_diff_capacity_nm+.000001,"Coupling respects torque capacity")
				check((sim.rear_right_omega-sim.rear_left_omega)*difference >= -.000001,"Coupling cannot overshoot equalisation")
				check(after_energy <= before_energy+.000001 and absf(before_energy-after_energy-sim.rear_coupling_dissipation_j) < .000001,"Dissipation matches removed rotational energy")
	check(not sim.set_rear_differential(NAN,.1,20) and not sim.set_rear_differential(.3,INF,20) and not sim.set_rear_differential(.3,.1,-1) and not sim.set_rear_differential(1.1,.1,20) and not sim.set_rear_differential(.3,.1,201),"Invalid settings rejected atomically")
	check(is_equal_approx(sim.rear_diff_drive_lock,.3) and is_equal_approx(sim.rear_diff_coast_lock,.1) and sim.rear_diff_preload_nm == 20,"Rejected changes preserve settings")
	sim._couple_rear_wheels(0,400)
	check(is_finite(sim.rear_omega) and sim.rear_coupling_torque_nm == 0,"Zero-duration coupling remains finite")
	# Airborne torque balance isolates the driveline from tyre/body forces.
	sim = seeded(25)
	sim.gear = 2
	sim.automatic = false
	sim.clutch = 1
	sim._independent_rear_active = true
	sim.rear_left_omega = 60
	sim.rear_right_omega = 80
	sim.rear_omega = 70
	sim.engine_omega = 70*sim.ratio()+10
	sim.clutch_torque_min_nm = INF
	sim.clutch_torque_max_nm = -INF
	sim._integrate(.0001,.5,0,0,0,0,9.81,false,1,INF)
	var wheel_torque: float = parameters.rear_axle_inertia_kgm2*.5*(sim.rear_left_omega+sim.rear_right_omega-140)/.0001
	check(absf(wheel_torque-sim.clutch_torque_max_nm*sim.ratio()*parameters.efficiency) < .00001,"Split drive torque preserves axle inertia and carrier reaction")
	check(sim.wheel_forces[2] == Vector2.ZERO and sim.wheel_forces[3] == Vector2.ZERO,"Airborne coupling adds no tyre force")
	# Straight driving must stay symmetric in forward and reverse.
	for pedal in [Vector2.ZERO,Vector2(.4,0),Vector2(0,.5)]:
		for direction in [1.0,-1.0]:
			var split = seeded(25*direction)
			split.gear = 2 if direction > 0 else -1
			split.automatic = false
			split.clutch = 1
			split.engine_omega = split.rear_omega*split.ratio()
			split.p.reverse_limit_kph = 200
			for i in range(120):
				split.advance(1.0/60,pedal.x,pedal.y,0)
			check(absf(split.rear_left_omega-split.rear_right_omega) < .000001,"Straight wheel speeds agree")
			check(absf(split.yaw_rate) < .000001 and is_finite(split.u),"Straight driving stays finite without yaw")
	# Assist intervention must use individual contact speeds.
	for direction in [-1.0,1.0]:
		for braking in [false,true]:
			sim = seeded(25*direction)
			sim.yaw_rate = .3*direction
			sim.gear = 2 if direction > 0 else -1
			sim.p.traction_control = 1
			sim._independent_rear_active = true
			sim.rear_left_omega = 0 if braking else 500*direction
			sim.rear_right_omega = sim.rear_left_omega
			sim.rear_omega = sim.rear_left_omega
			sim._integrate(.0001,0 if braking else 1,1 if braking else 0,0,0,0,9.81,true,1,INF)
			for side in [0,1]:
				var contact: float = 25*direction+.3*direction*parameters.rear_track_m*.5*(-1 if side == 0 else 1)
				var wheel: float = sim.rear_left_omega if side == 0 else sim.rear_right_omega
				var bound: float = absf(contact)/parameters.rear_radius_m*(1-parameters.braking_slip_limit if braking else 1+parameters.traction_slip_limit)
				check(wheel*direction >= bound-.000001 if braking else wheel*direction <= bound+.000001,"ABS/TC bound uses each rear contact")
	sim.reset()
	check(is_equal_approx(sim.rear_diff_drive_lock,.3) and sim.rear_left_omega == 0 and sim.rear_right_omega == 0 and not sim._independent_rear_active,"Pit reset retains settings and clears wheel state")

func run_comparison() -> void:
	load_parameters()
	mechanics()
	var output: Array = []
	for config in [Vector3(.3,.1,20),Vector3.ZERO,Vector3(.6,.3,40)]:
		settings = config
		for bank in [0.0,24.0]:
			var row := steady_case(1,bank)
			refine = true
			var fine := steady_case(1,bank)
			refine = false
			row["settings"] = [config.x,config.y,config.z]
			row["refinement_beta_error_deg"] = absf(row.beta_deg-fine.beta_deg)
			check(row.refinement_beta_error_deg < .02,"Clutch steady corner converges")
			output.append(row)
		for mode in ["power","brake","brake_reverse"]:
			for delay in [0.0,.2]:
				var row := recovery_case(mode,delay,1)
				var mirror := recovery_case(mode,delay,-1)
				check(absf(row.peak_beta-mirror.peak_beta) < .000001,"Clutch controlled response mirrors")
				refine = true
				var fine := recovery_case(mode,delay,1)
				refine = false
				row["settings"] = [config.x,config.y,config.z]
				row["refinement_peak_error_deg"] = absf(row.peak_beta-fine.peak_beta)
				row["refinement_outcome"] = fine.outcome
				check(row.outcome == fine.outcome,"Clutch recovery outcome survives refinement")
				print("DIFFERENTIAL settings=%s %s delay=%.1f peak=%.3f refine=%.4f %s" % [config,mode,delay,row.peak_beta,row.refinement_peak_error_deg,row.outcome])
				output.append(row)
	var file := FileAccess.open("res://tmp/icr2_analysis/rear_differential_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"results":output,"human_driving":false,"failures":failures},"\t"))
	await ui_and_telemetry()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("REAR DIFFERENTIAL PASSED: torque/energy, drive/coast/reverse, straight regression, ABS/TC, reset/defaults, mirror/refinement, live F10 and CSV.")
	quit(0 if failures.is_empty() else 1)

func ui_and_telemetry() -> void:
	var scene = load("res://game/main/main.tscn").instantiate()
	scene.ai_enabled = false
	root.add_child(scene)
	await process_frame
	var player = scene.player
	player.set_physics_process(false)
	var panel = scene.get_node("HUD/RaceUI/Shell/Layout/Content/Pages/ControlsPanel")
	check(player.sim.rear_differential_active() and player.sim.handling_model_id() == "wheel_contacts_rear_differential_v1", "New session uses rear differential by default")
	check(panel.find_child("HandlingModel", true, false) == null, "Retired model selector is removed")
	var fields: Array = panel.differential_fields
	check(fields.size() == 3 and fields[0].value == 30 and fields[1].value == 10 and fields[2].value == 20,"Trial controls show starting settings")
	fields[0].value = 45
	fields[1].value = 15
	fields[2].value = 25
	check(player.sim.rear_diff_drive_lock == .45 and player.sim.rear_diff_coast_lock == .15 and player.sim.rear_diff_preload_nm == 25,"F10 settings update live physics")
	player.sim.reset()
	check(player.sim.rear_differential_active() and player.sim.rear_diff_preload_nm == 25,"Pit reset retains differential selection")
	player.telemetry.stop()
	assert(player.telemetry.start(player,"res://tmp/icr2_analysis/differential_telemetry") == OK)
	for sample in range(3):
		player.sim.u = 25
		player.sim.gear = 0
		player.sim.rear_omega = 25/player.sim.p.rear_radius_m
		player.sim.advance(1.0/60,0,0,.05)
		player.telemetry.record(player,1.0/60,Vector3.ZERO,Vector3.UP,Vector3(0,0,9.81),1,true,Vector3.ZERO)
		check(fields[0].editable,"Differential controls follow active selection")
	player.telemetry.stop()
	var csv := FileAccess.open(player.telemetry.path,FileAccess.READ)
	var header := csv.get_csv_line()
	for column in ["rear_differential_active","rear_left_omega_rad_s","rear_right_omega_rad_s","rear_diff_drive_lock","rear_diff_coast_lock","rear_diff_preload_nm","rear_diff_drive_phase","rear_diff_capacity_nm","rear_coupling_torque_nm","rear_coupling_dissipation_j"]:
		check(column in header,"Differential telemetry: "+column)
	for index in range(3):
		var row := csv.get_csv_line()
		check(row.size() == header.size(),"Differential CSV rows match schema")
		check(row[header.find("rear_differential_active")] == "1","CSV records active default model")
		check(row[header.find("handling_model")] == "wheel_contacts_rear_differential_v1","Distinct differential telemetry identity")
		check(float(row[header.find("rear_diff_preload_nm")]) == 25,"CSV records session settings")
	var metadata := ConfigFile.new()
	assert(metadata.load(player.telemetry.path.get_basename()+".cfg") == OK)
	check(metadata.get_value("run","tyre_load_curve").model == "icr2_load_polynomial_trial_v1","Metadata identifies the tyre load trial")
	check(metadata.get_value("run","rear_differential").icr2_verified == false,"Metadata identifies experimental clutch hypothesis")
	if "--capture" in OS.get_cmdline_user_args():
		scene.get_node("HUD/RaceUI").open_page("controls")
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/icr2_analysis/differential_controls.png")
	scene.queue_free()
	await process_frame
	var fresh = load("res://game/main/main.tscn").instantiate()
	fresh.ai_enabled = false
	root.add_child(fresh)
	check(fresh.player.sim.rear_differential_active() and is_equal_approx(fresh.player.sim.rear_diff_drive_lock,.3) and fresh.player.sim.rear_diff_preload_nm == 20,"New session restores default handling and trial settings")
	fresh.queue_free()
	await process_frame
