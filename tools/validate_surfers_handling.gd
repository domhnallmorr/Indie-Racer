extends SceneTree
const Model = preload("res://game/vehicle/bicycle_model.gd")
var failures: Array[String] = []

func replay(window: Dictionary, columns: Array, subdivisions: int) -> float:
	var metadata := ConfigFile.new()
	assert(metadata.load("res://tools/fixtures/surfers_downshift.cfg") == OK)
	var p: Dictionary = metadata.get_value("run","physics")
	assert(is_equal_approx(p.front_brake_bias,.57))
	var sim = Model.new()
	sim.configure(p)
	sim.direct_steering = true
	var r: Dictionary = window.initial
	sim.set_vehicle_mass(r.vehicle_mass_kg)
	sim.u = r.u_mps
	sim.v = r.v_left_mps
	sim.yaw_rate = deg_to_rad(r.yaw_deg_s)
	sim.steer = deg_to_rad(r.steer_deg)
	sim.gear = int(r.gear)
	sim.engine_omega = r.rpm*Model.RPM_TO_RAD
	sim.clutch = 1.0
	sim.throttle = r.throttle_input
	sim.load_transfer_acceleration = r.load_transfer_accel_mps2
	sim.acceleration = r.longitudinal_accel_mps2
	sim.lateral_contact_acceleration = r.lateral_contact_accel_mps2
	var fl: float = sim.u*cos(sim.steer)+(sim.v+p.wheelbase_m*(1-p.front_weight_fraction)*sim.yaw_rate)*sin(sim.steer)
	sim.front_omega = (fl+r.front_slip_ratio*maxf(absf(fl),p.slip_reference_speed_mps))/p.front_radius_m
	sim.rear_omega = (sim.u+r.rear_slip_ratio*maxf(absf(sim.u),p.slip_reference_speed_mps))/p.rear_radius_m
	var peak := 0.0
	for frame in window.frames:
		r = {}
		for i in range(columns.size()): r[columns[i]] = frame[i]
		sim.set_vehicle_mass(r.vehicle_mass_kg)
		for i in range(subdivisions):
			sim.advance(r.dt_s/subdivisions,r.throttle_input,r.brake_input,r.steering_input,r.gravity_forward_mps2,r.gravity_left_mps2,r.normal_gravity_mps2,r.grounded>0,r.grip_scale)
			peak = maxf(peak,absf(rad_to_deg(atan2(sim.v,absf(sim.u)))))
	return peak

func _initialize() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/surfers_handling.json"))
	for window in fixture.windows:
		var reference := replay(window,fixture.columns,4)
		for subdivisions in [1,2]:
			var peak := replay(window,fixture.columns,subdivisions)
			if absf(peak-reference) > .5: failures.append("Recorded handling must converge at "+str(60*subdivisions)+" Hz, entry "+str(window.start))
			if window.start == 170.5 and peak > 5: failures.append("First-gear entry should avoid the previous numerical breakaway")
			if window.start == 186.5 and peak > 8: failures.append("Direct wheel correction should catch the recorded first-gear slide")
			print("SURFERS HANDLING start=%.1f hz=%d peak_sideslip=%.3f reference=%.3f" % [window.start,60*subdivisions,peak,reference])
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("SURFERS HANDLING PASSED: first-gear improvement, faithful wheel response and higher-gear convergence; brake bias remains 57%.")
	quit(0 if failures.is_empty() else 1)
