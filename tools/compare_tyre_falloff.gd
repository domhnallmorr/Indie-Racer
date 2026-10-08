extends SceneTree
## Isolated experiment: does not change the vehicle configuration or saved setup.
## Run headless with --script res://tools/compare_tyre_falloff.gd.
const Model = preload("res://game/vehicle/bicycle_model.gd")
const WIDTHS := [2.0,3.0,4.0]
var failures: Array[String] = []
var results: Array = []
var parameters: Dictionary
var fine_model: GDScript

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func beta(sim) -> float:
	return rad_to_deg(atan2(sim.v,absf(sim.u)))

func rear_lateral_force(sim) -> float:
	# Reconstruct the last integrated tyre force from its stored slip/load state.
	var force := 0.0
	for index in [2,3]:
		force += .5*sim._tyre(2.0*sim.wheel_loads[index],sim.rear_slip_ratio,sim.rear_slip_angle,sim.p.rear_cornering_stiffness_n_rad,1.0).y
	return force

func make_sim(width: float, fine := false):
	var sim = fine_model.new() if fine else Model.new()
	sim.configure(parameters.duplicate(true))
	sim.p.post_peak_falloff = width
	sim.direct_steering = true
	return sim

func _initialize() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/surfers_tyre_falloff.json"))
	var metadata := ConfigFile.new()
	if metadata.load(fixture.metadata) != OK:
		push_error("Missing replay metadata")
		quit(1)
		return
	parameters = metadata.get_value("run","physics")
	# Refine only the force integration. Changing advance() cadence also changes
	# automatic-shift decision timing, which is a separate source of divergence.
	var source := FileAccess.get_file_as_string("res://game/vehicle/bicycle_model.gd")
	if not source.contains("MAX_INTEGRATION_STEP_S := .0005") or not source.contains(".8/clutch_rate"):
		push_error("Update refinement harness for the current integration bounds")
		quit(1)
		return
	fine_model = GDScript.new()
	fine_model.source_code = source.replace("MAX_INTEGRATION_STEP_S := .0005","MAX_INTEGRATION_STEP_S := .00025").replace(".8/clutch_rate",".4/clutch_rate")
	fine_model.source_code = fine_model.source_code.replace("SHIFT_INTEGRATION_STEP_S := .000125","SHIFT_INTEGRATION_STEP_S := .0000625")
	if fine_model.reload() != OK:
		quit(1)
		return
	check(is_equal_approx(parameters.front_brake_bias,.57),"Experiment retains 57% brake bias")
	for width in WIDTHS:
		check_curve(width)
		for window in fixture.windows:
			var row := replay(window,fixture.columns,width,1)
			var fine := replay(window,fixture.columns,width,2)
			row["convergence_deg"] = absf(row.peak_beta-fine.peak_beta)
			row["refined_peak_beta"] = fine.peak_beta
			# Report sensitivity of sliding trajectories rather than hiding it in
			# a looser tolerance; clean-corner convergence remains a required check.
			row["numerically_sensitive"] = row.convergence_deg >= .5
			if window.name.begins_with("clean_"):
				check(not row.numerically_sensitive,window.name+": clean replay must converge with halved integration step")
			elif row.numerically_sensitive:
				print("SENSITIVE: ",window.name," width=",width," refinement changes peak by ",row.convergence_deg," degrees")
			results.append(row)
			print("REPLAY %s width=%.0f peak=%.3f recorded=%.3f error=%.3f convergence=%.3f" % [window.name,width,row.peak_beta,row.recorded_peak,row.max_replay_error,row.convergence_deg])
		for mode in ["power","brake"]:
			for delay in [0.0,.1,.2]:
				var left := controlled(width,mode,delay,1.0)
				var right := controlled(width,mode,delay,-1.0)
				check(absf(left.peak_beta-right.peak_beta)<.001,"Mirrored recovery must agree")
				results.append(left)
				print("RECOVERY %s width=%.0f delay=%.1f onset=%.3f peak=%.3f end=%.3f recovered=%.3f" % [mode,width,delay,left.onset,left.peak_beta,left.end_beta,left.recovery_seconds])
			var held := controlled(width,mode,99.0,1.0)
			results.append(held)
			print("HELD %s width=%.0f peak=%.3f" % [mode,width,held.peak_beta])
		results.append(steady_corner(width,false))
		results.append(steady_corner(width,true))
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var file := FileAccess.open("res://tmp/tyre_falloff_comparison.json",FileAccess.WRITE)
	if file == null:
		push_error("Cannot write tyre falloff comparison results")
		quit(1)
		return
	file.store_string(JSON.stringify(results,"\t"))
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("TYRE FALLOFF HARNESS PASSED: force limits, symmetry, early recovery and clean-corner convergence. Historical replay differences and held-input outcomes are reported separately; no default-setting approval is implied.")
	quit(0 if failures.is_empty() else 1)

func check_curve(width: float) -> void:
	var sim = make_sim(width)
	var baseline = make_sim(2.0)
	for load_n in [500.0,3500.0,7000.0]:
		var stiffness: float = parameters.rear_cornering_stiffness_n_rad
		var peak: float = sim._peak_force(load_n,1.0)
		var scale: float = pow(load_n/parameters.reference_load_n,parameters.load_stiffness_exponent)
		var angle: float = PI/2.0*peak/(stiffness*scale)
		for fraction in [.001,.5,1.0]:
			check(sim._tyre(load_n,0,angle*fraction,stiffness,1).is_equal_approx(baseline._tyre(load_n,0,angle*fraction,stiffness,1)),"Pre-peak tyre response unchanged")
		check(absf(sim._tyre(load_n,0,angle*30,stiffness,1).length()/peak-.85)<.000001,"Sliding asymptote remains 85%")
		var previous := peak
		for step in range(101):
			var force: Vector2 = sim._tyre(load_n,0,angle*(1+step*.1),stiffness,1)
			check(force.length()<=previous+.001,"Post-peak force falls monotonically")
			previous = force.length()
		for slip in [-.5,-.12,0.0,.12,.5]:
			for alpha in [-.3,-.05,0.0,.05,.3]:
				var force: Vector2 = sim._tyre(load_n,slip,alpha,stiffness,1)
				check(force.length()<=peak+.001,"Combined force stays within friction limit")
				check(force.is_equal_approx(-sim._tyre(load_n,-slip,-alpha,stiffness,1)),"Force sign symmetry")

func replay(window: Dictionary, columns: Array, width: float, refinement: int) -> Dictionary:
	var sim = make_sim(width,refinement>1)
	var r: Dictionary = window.initial
	sim.set_vehicle_mass(r.vehicle_mass_kg)
	sim.u = r.u_mps
	sim.v = r.v_left_mps
	sim.yaw_rate = deg_to_rad(r.yaw_deg_s)
	sim.steer = deg_to_rad(r.steer_deg)
	sim.gear = int(r.gear)
	sim.engine_omega = r.rpm*Model.RPM_TO_RAD
	sim.clutch = r.clutch_engagement
	sim.throttle = r.engine_opening
	sim.load_transfer_acceleration = r.load_transfer_accel_mps2
	sim.acceleration = r.longitudinal_accel_mps2
	sim.lateral_contact_acceleration = r.lateral_contact_accel_mps2
	var fl: float = sim.u*cos(sim.steer)+(sim.v+parameters.wheelbase_m*(1-parameters.front_weight_fraction)*sim.yaw_rate)*sin(sim.steer)
	sim.front_omega = (fl+r.front_slip_ratio*maxf(absf(fl),parameters.slip_reference_speed_mps))/parameters.front_radius_m
	sim.rear_omega = (sim.u+r.rear_slip_ratio*maxf(absf(sim.u),parameters.slip_reference_speed_mps))/parameters.rear_radius_m
	var peak := 0.0
	var recorded_peak := 0.0
	var error := 0.0
	var peak_yaw := 0.0
	var trace: Array = []
	var force_trace: Array = []
	var step_times: Array = []
	for frame in window.frames:
		r = {}
		for i in range(columns.size()): r[columns[i]] = frame[i]
		sim.set_vehicle_mass(r.vehicle_mass_kg)
		var normal := Vector3(r.normal_x,r.normal_y,r.normal_z)
		var forward := Vector3(-sin(deg_to_rad(r.heading_deg)),0,-cos(deg_to_rad(r.heading_deg))).slide(normal).normalized()
		var left := normal.cross(forward).normalized()
		sim.turn_normal_factors = Vector2(Vector3.UP.cross(forward).dot(normal),Vector3.UP.cross(left).dot(normal))
		var started := Time.get_ticks_usec()
		sim.advance(r.dt_s,r.throttle_input,r.brake_input,r.steering_input,r.gravity_forward_mps2,r.gravity_left_mps2,r.normal_gravity_mps2,r.grounded>0,r.grip_scale)
		step_times.append((Time.get_ticks_usec()-started)/1000.0)
		peak = maxf(peak,absf(beta(sim)))
		peak_yaw = maxf(peak_yaw,absf(rad_to_deg(sim.yaw_rate)))
		recorded_peak = maxf(recorded_peak,absf(r.beta_deg))
		error = maxf(error,absf(beta(sim)-r.beta_deg))
		trace.append([r.time_s,beta(sim),rad_to_deg(sim.yaw_rate),sim.rear_slip_ratio,sim.gear,sim.rpm()])
		var front := Vector2.ZERO
		var rear := Vector2.ZERO
		for index in [0,1]:
			front += .5*sim._tyre(2.0*sim.wheel_loads[index],sim.front_slip_ratio,sim.front_slip_angle,sim.p.front_cornering_stiffness_n_rad,r.grip_scale)
		for index in [2,3]:
			rear += .5*sim._tyre(2.0*sim.wheel_loads[index],sim.rear_slip_ratio,sim.rear_slip_angle,sim.p.rear_cornering_stiffness_n_rad,r.grip_scale)
		var body_front_y: float = front.x*sin(sim.steer)+front.y*cos(sim.steer)
		var front_moment: float = sim.p.wheelbase_m*(1.0-sim.p.front_weight_fraction)*body_front_y
		var rear_moment: float = -sim.p.wheelbase_m*sim.p.front_weight_fraction*rear.y
		force_trace.append([r.time_s,front.x,front.y,rear.x,rear.y,front_moment,rear_moment,sim.front_load,sim.rear_load,sim.u*sim.yaw_rate,(body_front_y+rear.y)/sim.vehicle_mass_kg])
	# The fixture predates second-order integration. Report differences from
	# the historical recording; validate_integration_accuracy checks numerical
	# accuracy against a refined solver, not agreement with the old Euler error.
	return {"kind":"replay","name":window.name,"width":width,"peak_beta":peak,"peak_yaw":peak_yaw,"recorded_peak":recorded_peak,"max_replay_error":error,"trace":trace,"force_trace_columns":["time_s","front_fx_n","front_fy_n","rear_fx_n","rear_fy_n","front_yaw_moment_nm","rear_yaw_moment_nm","front_load_n","rear_load_n","u_times_yaw_mps2","tyre_lateral_accel_mps2"],"force_trace":force_trace,"physics_step_ms":step_times}

func controlled(width: float, mode: String, delay: float, direction: float) -> Dictionary:
	var sim = make_sim(width)
	sim.u = 25.0 if mode == "power" else 40.0
	sim.gear = 2 if mode == "power" else 4
	sim.automatic = false
	sim.clutch = 1.0
	sim.front_omega = sim.u/parameters.front_radius_m
	sim.rear_omega = sim.u/parameters.rear_radius_m
	sim.engine_omega = sim.rear_omega*sim.ratio()
	sim.throttle = .2
	var onset := -1.0
	var peak := 0.0
	var peak_yaw := 0.0
	var recovered := -1.0
	var settled := 0.0
	var previous_support := 0.0
	var max_support_drop := 0.0
	var trace: Array = []
	for i in range(420):
		var t := i/60.0
		var gas := .2
		var brake := 0.0
		var angle := 2.0*direction
		if t>=1.0:
			gas = 1.0 if mode == "power" else 0.0
			brake = .55 if mode.begins_with("brake") else 0.0
			angle = (4.0 if mode.begins_with("brake") else 2.0)*direction
			if mode == "brake_reverse":
				brake = .85
				angle = -4.0*direction
		if onset>=0 and t>=onset+delay:
			gas = .1
			brake = 0.0
			# Identical state feedback for all widths; a reproducible synthetic
			# correction, not a model of the human driver's reaction or skill.
			angle = clampf(beta(sim)*.6-rad_to_deg(sim.yaw_rate)*.08,-8,8)
		sim.advance(1.0/60,gas,brake,angle/sim.steering_lock_at_speed(Vector2(sim.u,sim.v).length()))
		if t>=1.0 and onset<0 and absf(beta(sim))>=3.0: onset=t+1.0/60
		peak = maxf(peak,absf(beta(sim)))
		peak_yaw = maxf(peak_yaw,absf(rad_to_deg(sim.yaw_rate)))
		var support := rear_lateral_force(sim)
		# Exclude countersteer/recovery: changing force direction deliberately is
		# not loss of grip. This is a sampled rate, not an internal-step maximum.
		if t>=1.0 and (onset<0 or t<onset+delay):
			max_support_drop = maxf(max_support_drop,(absf(previous_support)-absf(support))*60.0)
		previous_support = support
		if onset>=0 and t>=onset+delay:
			settled = settled+1.0/60 if absf(beta(sim))<1 and absf(sim.yaw_rate)<.05 else 0.0
			if settled>=.3 and recovered<0: recovered=t-onset-delay-.3
		trace.append([t,beta(sim),rad_to_deg(sim.yaw_rate),sim.rear_slip_ratio,support])
	check(onset>=0,"Controlled "+mode+" test must provoke breakaway")
	# The original early-catch contract covers up to 0.2 s. Longer delays are
	# stress cases: report their outcome rather than require recovery by design.
	if delay <= .2:
		check(recovered>=0 and absf(beta(sim))<1 and sim.u>10,"Early correction must recover without stopping or reversing")
	return {"kind":"controlled","name":mode,"width":width,"delay":delay,"onset":onset,"peak_beta":peak,"peak_yaw":peak_yaw,"end_beta":absf(beta(sim)),"end_speed":sim.u,"recovery_seconds":recovered,"max_rear_support_drop_n_s":max_support_drop,"trace_columns":["time_s","beta_deg","yaw_deg_s","rear_slip_ratio","rear_lateral_force_n"],"trace":trace}

func steady_corner(width: float, high_speed: bool) -> Dictionary:
	var sim = make_sim(width)
	sim.gear = 0
	var speed := 200.0/3.6 if high_speed else 25.0
	for i in range(600):
		sim.u = speed
		sim.front_omega = speed/parameters.front_radius_m
		sim.rear_omega = speed/parameters.rear_radius_m
		var angle := 2.0
		sim.advance(1.0/60,0,0,angle/sim.steering_lock_at_speed(Vector2(sim.u,sim.v).length()))
	var row := {"kind":"steady","name":"fast" if high_speed else "slow","width":width,"beta":beta(sim),"yaw":rad_to_deg(sim.yaw_rate),"radius":sim.u/sim.yaw_rate}
	print("STEADY ",row)
	return row
