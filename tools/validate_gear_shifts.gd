extends SceneTree
const Model = preload("res://game/vehicle/bicycle_model.gd")
const Config = preload("res://game/vehicle/physics_config.gd")
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func moving(p: Dictionary, selected: int, coupled_rpm: float):
	var model = Model.new()
	model.configure(p.duplicate(true))
	model.gear = selected
	model.rear_omega = coupled_rpm*Model.RPM_TO_RAD/model.ratio()
	model.u = model.rear_omega*p.rear_radius_m
	model.front_omega = model.u/p.front_radius_m
	model.engine_omega = coupled_rpm*Model.RPM_TO_RAD
	model.clutch = 1.0
	return model

func validate_downshifts(p: Dictionary, hz: int) -> void:
	var dt := 1.0/hz
	var falling_revs = moving(p,5,10000)
	falling_revs.engine_omega = 5000*Model.RPM_TO_RAD
	falling_revs.advance(dt,0,0,0)
	check(falling_revs.gear == 5,"Engine RPM falling alone must not request a downshift")
	var reconnecting = moving(p,4,7000)
	reconnecting.clutch = .3
	reconnecting.advance(dt,0,0,0)
	check(reconnecting.gear == 4,"Wait for clutch engagement before the next automatic downshift")
	check(reconnecting.select_gear(3),"Manual selection remains available during clutch reconnection")
	check(not reconnecting.automatic_rev_match,"Manual shifts do not enable the automatic blip")
	var locked_rear = moving(p,4,10000)
	locked_rear.rear_omega *= .3
	locked_rear.engine_omega = 3000*Model.RPM_TO_RAD
	locked_rear.advance(dt,0,1,0)
	check(locked_rear.gear == 4,"Rear wheel braking slip must not request a premature downshift")
	var spinning_rear = moving(p,4,7000)
	spinning_rear.rear_omega *= 1.5
	spinning_rear.advance(dt,0,0,0)
	check(spinning_rear.gear == 4,"Spinning wheels must not request a downshift from low road RPM")
	var wide_ratio = moving(p,2,7500)
	wide_ratio.p.forward_ratios[0] = 5.4
	wide_ratio.advance(dt,0,0,0)
	check(wide_ratio.gear == 2,"Do not downshift into the automatic upshift range")
	var matched = moving(p,4,7000)
	var unblipped = moving(p,4,7000)
	unblipped.automatic = false
	unblipped.select_gear(3)
	matched.advance(dt,0,0,0)
	unblipped.advance(dt,0,0,0)
	check(matched.gear == 3 and matched.automatic_rev_match,"Valid automatic downshift starts a rev match")
	while matched.shift_remaining > 0:
		check(matched.clutch == 0,"Rev matching keeps the shift clutch open")
		matched.advance(dt,0,0,0)
		unblipped.advance(dt,0,0,0)
	var rpm_error: float = absf(matched.rpm()-matched.rear_omega*matched.ratio()/Model.RPM_TO_RAD)
	check(rpm_error < 200,"Engine approaches wheel-driven RPM before clutch reconnects: "+str(rpm_error))
	check(not matched.automatic_rev_match,"Blip ends with the shift interval")
	var matched_slip := 0.0
	var unblipped_slip := 0.0
	for i in range(hz/2):
		matched.advance(dt,0,0,0)
		unblipped.advance(dt,0,0,0)
		matched_slip = minf(matched_slip,matched.rear_slip_ratio)
		unblipped_slip = minf(unblipped_slip,unblipped.rear_slip_ratio)
	check(matched.gear == 3,"One downshift does not cascade into lower gears")
	check(matched_slip > unblipped_slip+.02,"Rev match reduces rear braking slip during reconnection")
	check(matched.rear_slip_ratio < -.001 and matched.u < p.rear_radius_m*7000*Model.RPM_TO_RAD/(p.forward_ratios[3]*p.final_drive),"Normal engine braking remains after the blip")
	print("DOWNSHIFT hz=%d assist=%.0f reconnect_error=%.1f rpm rear_slip=%.3f unblipped=%.3f" % [hz,p.assistance_strength,rpm_error,matched_slip,unblipped_slip])
	var stopped = moving(p,4,0)
	stopped.engine_omega = p.idle_rpm*Model.RPM_TO_RAD
	stopped.clutch = 0
	for i in range(hz): stopped.advance(dt,0,1,0)
	check(stopped.gear == 1,"Stopped car returns to first with the launch clutch disengaged")
	var off = moving(p,4,7000)
	off.set_engine_running(false)
	off.advance(dt,0,0,0)
	check(off.gear == 4 and not off.automatic_rev_match,"Engine-off car cannot start an automatic downshift/blip")
	matched.automatic_rev_match = true
	matched.reset()
	check(not matched.automatic_rev_match,"Reset clears rev matching")

func replay_surfers(subdivisions: int) -> float:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/surfers_downshift.json"))
	var metadata := ConfigFile.new()
	check(metadata.load("res://tools/fixtures/surfers_downshift.cfg") == OK,"Surfers recorded configuration loads")
	var p: Dictionary = metadata.get_value("run","physics")
	var first: Dictionary = fixture.initial
	var model = Model.new()
	model.configure(p)
	model.set_vehicle_mass(first.vehicle_mass_kg)
	model.u = first.u_mps
	model.v = first.v_left_mps
	model.yaw_rate = deg_to_rad(first.yaw_deg_s)
	model.steer = deg_to_rad(first.steer_deg)
	model.gear = int(first.gear)
	model.engine_omega = first.rpm*Model.RPM_TO_RAD
	model.clutch = 1.0
	model.throttle = first.throttle_input
	model.load_transfer_acceleration = first.load_transfer_accel_mps2
	model.acceleration = first.longitudinal_accel_mps2
	model.lateral_contact_acceleration = first.lateral_contact_accel_mps2
	var front_long: float = model.u*cos(model.steer)+(model.v+p.wheelbase_m*(1-p.front_weight_fraction)*model.yaw_rate)*sin(model.steer)
	model.front_omega = (front_long+first.front_slip_ratio*maxf(absf(front_long),p.slip_reference_speed_mps))/p.front_radius_m
	model.rear_omega = (model.u+first.rear_slip_ratio*maxf(absf(model.u),p.slip_reference_speed_mps))/p.rear_radius_m
	var peak := 0.0
	var shifts: Array[int] = []
	for frame in fixture.frames:
		var r := {}
		for i in range(fixture.columns.size()): r[fixture.columns[i]] = frame[i]
		model.set_vehicle_mass(r.vehicle_mass_kg)
		for i in range(subdivisions):
			var previous: int = model.gear
			model.advance(r.dt_s/subdivisions,r.throttle_input,r.brake_input,r.steering_input,r.gravity_forward_mps2,r.gravity_left_mps2,r.normal_gravity_mps2,r.grounded>0,r.grip_scale)
			if model.gear != previous: shifts.append(model.gear)
			peak = maxf(peak,absf(rad_to_deg(atan2(model.v,absf(model.u)))))
	check(peak < 13,"Surfers downshift entry sideslip remains below 13 degrees: "+str(peak))
	check(model.gear >= 3,"Surfers braking entry no longer cascades into second")
	check(not shifts.is_empty(),"Surfers replay still downshifts as the car slows")
	print("SURFERS DOWNSHIFT hz=%d peak_sideslip=%.3f gears=%s speed=%.1f" % [60*subdivisions,peak,shifts,Vector2(model.u,model.v).length()*3.6])
	return peak

func _initialize() -> void:
	var config = Config.new()
	if not config.load_directory("res://content/vehicles/open_wheel/physics"):
		push_error(str(config.errors))
		quit(1)
		return
	for assistance in [1.0, 0.0]:
		for hz in [60, 120]:
			config.values.assistance_strength = assistance
			validate_downshifts(config.values,hz)
			var model = Model.new()
			model.configure(config.values)
			var seen: Array[int] = [1]
			for i in range(60*hz):
				var previous: int = model.gear
				var coupled_rpm: float = absf(model.rear_omega*model.ratio())/Model.RPM_TO_RAD
				model.advance(1.0/hz,1,0,0)
				if model.gear != previous:
					print("SHIFT assist=%.0f hz=%d t=%.2f %d->%d speed=%.1f coupled_rpm=%.0f" % [assistance,hz,float(i)/hz,previous,model.gear,model.u*3.6,coupled_rpm])
					if model.gear != previous+1:
						failures.append("Full-throttle acceleration must progress sequentially")
					if coupled_rpm < config.values.automatic_upshift_rpm:
						failures.append("Upshift before the current gear reaches its wheel-driven RPM threshold")
					if model.gear not in seen:
						seen.append(model.gear)
			if seen != [1,2,3,4,5,6]:
				failures.append("Acceleration must use all six gears: "+str(seen))
	var peak_60 := replay_surfers(1)
	var peak_120 := replay_surfers(2)
	check(absf(peak_60-peak_120) < .5,"Surfers downshift replay agrees at 60/120 Hz")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("GEAR SHIFTS PASSED: sequential acceleration, downshift timing, rev matching, braking slip guards and stopped recovery at 60/120 Hz, with and without assists.")
	quit(0 if failures.is_empty() else 1)
