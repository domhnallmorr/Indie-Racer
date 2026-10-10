extends "res://tools/compare_tyre_falloff.gd"
## Fresh synthetic driving, not human laps or a reconstructed ICR2 tyre model.
var refine := false

func make_sim(_width: float, _fine := false):
	var sim = fine_model.new() if refine else Model.new()
	sim.configure(parameters.duplicate(true))
	sim.direct_steering = true
	return sim

func _initialize() -> void:
	call_deferred("run_comparison")

func load_parameters() -> void:
	var metadata := ConfigFile.new()
	assert(metadata.load("res://tools/fixtures/surfers_downshift.cfg") == OK)
	parameters = metadata.get_value("run","physics")
	# Keep captured driving/aero inputs, but validate today's tyre calibration.
	var current := preload("res://game/vehicle/physics_config.gd").new()
	assert(current.load_directory("res://content/vehicles/open_wheel/physics"))
	parameters.friction_coefficient = current.values.friction_coefficient
	var source := FileAccess.get_file_as_string("res://game/vehicle/bicycle_model.gd")
	fine_model = GDScript.new()
	fine_model.source_code = source.replace("MAX_INTEGRATION_STEP_S := .0005","MAX_INTEGRATION_STEP_S := .00025").replace(".8/clutch_rate",".4/clutch_rate")
	assert(fine_model.reload() == OK)

func rear_lateral_force(sim) -> float:
	return sim.wheel_forces[2].y+sim.wheel_forces[3].y

func recovery_case(mode: String, delay: float, direction: float) -> Dictionary:
	# The previous axle harness assumes every brake turn-in must break away.
	# This harness also reports a stable turn-in, without inventing a slide.
	var sim = make_sim(2.0)
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
	var trace: Array = []
	for i in range(420):
		var t := i/60.0
		var gas := .2
		var brake := 0.0
		var angle := 2.0*direction
		if t >= 1.0:
			gas = 1.0 if mode == "power" else 0.0
			brake = .55 if mode.begins_with("brake") else 0.0
			angle = (4.0 if mode.begins_with("brake") else 2.0)*direction
			if mode == "brake_reverse":
				brake = .85
				angle = -4.0*direction
		if onset >= 0 and t >= onset+delay:
			gas = .1
			brake = 0.0
			angle = clampf(beta(sim)*.6-rad_to_deg(sim.yaw_rate)*.08,-8,8)
		sim.advance(1.0/60,gas,brake,angle/sim.steering_lock_at_speed(Vector2(sim.u,sim.v).length()))
		if t >= 1.0 and onset < 0 and absf(beta(sim)) >= 3.0:
			onset = t+1.0/60
		peak = maxf(peak,absf(beta(sim)))
		peak_yaw = maxf(peak_yaw,absf(rad_to_deg(sim.yaw_rate)))
		if onset >= 0 and t >= onset+delay:
			settled = settled+1.0/60 if absf(beta(sim)) < 1 and absf(sim.yaw_rate) < .05 else 0.0
			if settled >= .3 and recovered < 0:
				recovered = t-onset-delay-.3
		trace.append([t,beta(sim),rad_to_deg(sim.yaw_rate),sim.u,sim.wheel_slip_ratios[2],sim.wheel_slip_ratios[3],sim.wheel_forces[2].x,sim.wheel_forces[3].x,rear_lateral_force(sim),sim.rear_track_yaw_moment_nm])
	var outcome := "stable_turn_in" if onset < 0 else "recovered"
	if onset >= 0 and (recovered < 0 or absf(beta(sim)) >= 1 or sim.u <= 10):
		outcome = "failed_recovery"
	return {"kind":"recovery","name":mode,"delay":delay,"direction":direction,"onset":onset,"peak_beta":peak,"peak_yaw":peak_yaw,"end_beta":absf(beta(sim)),"end_speed":sim.u,"recovery_seconds":recovered,"outcome":outcome,
		"trace_columns":["time_s","beta_deg","yaw_deg_s","u_mps","rl_slip_ratio","rr_slip_ratio","rl_fx_n","rr_fx_n","rear_fy_n","rear_track_yaw_nm"],"trace":trace}

func steady_case(direction: float, bank_deg: float) -> Dictionary:
	var sim = make_sim(2.0)
	var speed := 25.0 if bank_deg == 0 else 60.0
	var bank := deg_to_rad(bank_deg)
	sim.gear = 0
	sim.u = speed
	sim.front_omega = speed/parameters.front_radius_m
	sim.rear_omega = speed/parameters.rear_radius_m
	sim.turn_normal_factors = Vector2(sin(bank)*direction,0)
	# Constant forward speed is an external test constraint, not engine tuning.
	for i in range(360):
		sim.u = speed
		var angle := (2.0 if bank_deg == 0 else .8)*direction
		sim.advance(1.0/60,0,0,angle/sim.steering_lock_at_speed(speed),0,-9.81*sin(bank)*direction,9.81*cos(bank))
	return {"kind":"steady","direction":direction,"bank_deg":bank_deg,"yaw_deg_s":rad_to_deg(sim.yaw_rate),"beta_deg":beta(sim),"radius_m":sim.u/sim.yaw_rate,"rl_slip_ratio":sim.wheel_slip_ratios[2],"rr_slip_ratio":sim.wheel_slip_ratios[3]}

