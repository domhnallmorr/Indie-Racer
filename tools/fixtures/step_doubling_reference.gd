# Offline accuracy experiment; never used by the driving model.
extends RefCounted
## Dynamic single-track model. Body axes: u forward, v left, yaw positive left.
## Forces are integrated on the road plane. Collision/vertical support is external.
var p: Dictionary
var vehicle_mass_kg := 0.0
var vehicle_yaw_inertia_kgm2 := 0.0
var u := 0.0
var v := 0.0
var yaw_rate := 0.0
var steer := 0.0
# Calibrated wheel input already describes an angle; only digital input needs slew.
var direct_steering := false
var integration_steps := 0
var clutch_torque_min_nm := 0.0
var clutch_torque_max_nm := 0.0
var engine_opening := 0.0
# Effective input range for telemetry; no grip/yaw-dependent steering gain.
var assisted_steering_lock_deg := 0.0
var front_omega := 0.0
var rear_omega := 0.0
var engine_omega := 0.0
var engine_running := true
var throttle := 0.0
var gear := 1
var automatic := true
var shift_remaining := 0.0
var automatic_rev_match := false
var clutch := 0.0
var acceleration := 0.0
# Contact-force equivalent acceleration drives pitch load transfer. Aero drag
# and gravity act at the CG and must not be treated as contact-patch braking.
var load_transfer_acceleration := 0.0
var load_transfer_n := 0.0
var front_slip_angle := 0.0
var rear_slip_angle := 0.0
var front_slip_ratio := 0.0
var rear_slip_ratio := 0.0
var front_usage := 0.0
var rear_usage := 0.0
var front_load := 0.0
var rear_load := 0.0
# Load-resolved tyres, ordered FL, FR, RL, RR. Axle slips/spin remain shared.
var wheel_loads := PackedFloat64Array([0.0,0.0,0.0,0.0])
var wheel_peaks := PackedFloat64Array([0.0,0.0,0.0,0.0])
var wheel_usage := PackedFloat64Array([0.0,0.0,0.0,0.0])
var wheel_demand := PackedFloat64Array([0.0,0.0,0.0,0.0])
var lateral_contact_acceleration := 0.0
var front_lateral_transfer_n := 0.0
var rear_lateral_transfer_n := 0.0
var drag_n := 0.0
const Slipstream = preload("res://game/vehicle/slipstream.gd")
var slipstream_target := 0.0
var slipstream_strength := 0.0
var slipstream_drag_reduction := 0.0
var dirty_air_target := 0.0
var dirty_air_strength := 0.0
var downforce_n := 0.0
var front_downforce_n := 0.0
var rear_downforce_n := 0.0
var airspeed_mps := 0.0
# Road-plane wind components, forward/left. Zero means still air.
var wind_body_mps := Vector2.ZERO
# Normal components of world-up rotation of each road-plane basis vector.
# Set by the player from the contact normal; zero on a flat road.
var turn_normal_factors := Vector2.ZERO
var banking_load_n := 0.0
var heading_change := 0.0
const RPM_TO_RAD := TAU/60.0
const AUTO_REV_MATCH_RESPONSE_S := .04
const INTEGRATION_SCHEME := "step_doubling_v1"
const MAX_INTEGRATION_STEP_S := .0005
const SHIFT_INTEGRATION_STEP_S := .000125

func configure(parameters: Dictionary) -> void:
	p = parameters
	vehicle_mass_kg = p.mass_kg
	vehicle_yaw_inertia_kgm2 = p.yaw_inertia_kgm2
	reset()

func set_vehicle_mass(total_mass_kg: float) -> void:
	vehicle_mass_kg = maxf(0.001,total_mass_kg)
	# Fuel is carried near the car's centre, so retain the authored inertia shape
	# while allowing the whole car to become easier to rotate as it burns off.
	vehicle_yaw_inertia_kgm2 = p.yaw_inertia_kgm2*vehicle_mass_kg/p.mass_kg

func reset() -> void:
	u = 0
	v = 0
	yaw_rate = 0
	steer = 0
	direct_steering = false
	integration_steps = 0
	clutch_torque_min_nm = 0.0
	clutch_torque_max_nm = 0.0
	engine_opening = 0.0
	assisted_steering_lock_deg = p.steering_lock_deg
	front_omega = 0
	rear_omega = 0
	engine_omega = p.idle_rpm*RPM_TO_RAD if engine_running else 0.0
	throttle = 0
	gear = 1
	shift_remaining = 0
	automatic_rev_match = false
	clutch = 0
	acceleration = 0
	load_transfer_acceleration = 0
	load_transfer_n = 0
	lateral_contact_acceleration = 0
	front_lateral_transfer_n = 0
	rear_lateral_transfer_n = 0
	front_load = 0
	rear_load = 0
	wheel_loads.fill(0.0)
	wheel_peaks.fill(0.0)
	wheel_usage.fill(0.0)
	wheel_demand.fill(0.0)
	heading_change = 0
	front_usage = 0
	rear_usage = 0
	drag_n = 0.0
	slipstream_target = 0.0
	slipstream_strength = 0.0
	slipstream_drag_reduction = 0.0
	dirty_air_target = 0.0
	dirty_air_strength = 0.0
	downforce_n = 0.0
	front_downforce_n = 0.0
	rear_downforce_n = 0.0
	airspeed_mps = 0.0
	banking_load_n = 0.0
	turn_normal_factors = Vector2.ZERO

func rpm() -> float:
	return engine_omega/RPM_TO_RAD

func set_engine_running(value: bool) -> void:
	engine_running = value
	automatic_rev_match = false
	engine_omega = p.idle_rpm*RPM_TO_RAD if value else 0.0
	throttle = 0.0
	clutch = 0.0

func ratio(for_gear: int = 99) -> float:
	if for_gear == 99:
		for_gear = gear
	if for_gear == 0:
		return 0
	return (-p.reverse_ratio if for_gear == -1 else p.forward_ratios[for_gear-1])*p.final_drive

func select_gear(requested: int) -> bool:
	if requested < -1 or requested > 6 or shift_remaining > 0 or requested == gear:
		return false
	if (requested == -1 or gear == -1) and Vector2(u,v).length() > p.direction_change_max_mps:
		return false
	var predicted: float = absf(rear_omega*ratio(requested))/RPM_TO_RAD
	if requested != 0 and predicted > p.redline_rpm:
		return false
	gear = requested
	shift_remaining = p.shift_time_s
	automatic_rev_match = false
	clutch = 0
	return true

func torque_at(at_rpm: float, opening: float) -> float:
	var curve: Array = p.torque_curve
	var row: Vector3 = curve[0]
	for i in range(1,curve.size()):
		if at_rpm <= curve[i].x:
			row = curve[i-1].lerp(curve[i],clampf((at_rpm-curve[i-1].x)/(curve[i].x-curve[i-1].x),0,1))
			return lerpf(row.y,row.z,opening)
	row = curve[-1]
	return lerpf(row.y,row.z,opening)

func advance(delta: float, gas: float, brake: float, steering_input: float,
		gravity_forward: float = 0, gravity_left: float = 0, normal_gravity: float = 9.81,
		grounded: bool = true, grip_scale: float = 1, speed_cap_mps: float = INF) -> void:
	heading_change = 0
	if automatic and gear > 0 and shift_remaining == 0:
		# Engine revs can remain high while the clutch reconnects after a shift.
		# Require the current ratio's wheel-driven RPM too, or that rev flare
		# immediately triggers more shifts before the car has accelerated.
		var coupled_rpm: float = absf(rear_omega*ratio())/RPM_TO_RAD
		if rpm() > p.automatic_upshift_rpm and coupled_rpm > p.automatic_upshift_rpm and gear < 6 and absf(rear_slip_ratio) < .20:
			select_gear(gear+1)
		elif engine_running and gear > 1:
			# Shift cuts let the engine slow while the clutch is open. Those revs
			# must not trigger another downshift before the current gear reconnects.
			# Road speed also guards against a braking rear axle under-reading RPM.
			var road_rpm: float = absf(u)/p.rear_radius_m*absf(ratio())/RPM_TO_RAD
			var downshift_rpm: float = maxf(coupled_rpm,road_rpm)
			# Below idle the launch clutch may never fully engage; allow the box
			# to return to first as the car stops, still respecting shift_time_s.
			var reconnected: bool = clutch >= .99 or downshift_rpm < p.idle_rpm
			var next_rpm: float = downshift_rpm*absf(ratio(gear-1)/ratio())
			if reconnected and maxf(rpm(),downshift_rpm) < p.automatic_downshift_rpm and next_rpm < p.automatic_upshift_rpm:
				if select_gear(gear-1):
					automatic_rev_match = true
	# The clutch couples engine inertia to axle inertia through ratio squared.
	# At the default first-gear ratio the old ~1 ms Euler step was unstable.
	# Bound its dimensionless response below one, including custom gearing,
	# and retain a separate small-step ceiling for the tyre/axle dynamics.
	var clutch_rate: float = p.clutch_stiffness_nm_s*(1.0/p.inertia_kgm2+ratio()*ratio()*p.efficiency/p.rear_axle_inertia_kgm2)
	var step_limit: float = minf(MAX_INTEGRATION_STEP_S,.8/clutch_rate)
	# Shift cut/rev-match and clutch engagement contain non-smooth events.
	# Resolve these more finely while moving. A wide torque margin at a nearly
	# unloaded clutch has no engagement-limit transition to resolve. Keep a
	# conservative tenfold margin, including available engine torque, before
	# skipping refinement. Gearbox decisions remain at the outer tick.
	var clutch_demand: float = absf(engine_omega-rear_omega*ratio())*p.clutch_stiffness_nm_s
	var engine_demand: float = absf(torque_at(rpm(),throttle))
	var small_torque: bool = maxf(clutch_demand,engine_demand) < .1*p.clutch_capacity_nm*clutch
	if shift_remaining > 0 or (engine_running and gear != 0 and absf(u) > 1 and clutch < 1.0 and not small_torque):
		step_limit = minf(step_limit,SHIFT_INTEGRATION_STEP_S)
	integration_steps = maxi(1,int(ceil(delta/step_limit)))
	clutch_torque_min_nm = INF
	clutch_torque_max_nm = -INF
	var dt := delta/integration_steps
	for unused in range(integration_steps):
		_integrate(dt,gas,brake,steering_input,gravity_forward,gravity_left,normal_gravity,grounded,grip_scale,speed_cap_mps)

func steering_lock_at_speed(speed: float) -> float:
	# Optional accessibility mapping. With help off, normalized input maps to
	# physical lock at every speed. Wings, tyre grip, bank and yaw never enter it.
	var reduction := clampf(absf(speed)/p.steering_reduction_speed_mps,0,1)
	return lerpf(p.steering_lock_deg,p.high_speed_lock_deg,reduction*p.assistance_strength*p.steering_assistance)

func _integrate(dt: float, gas: float, brake: float, steering_input: float, gx: float, gy: float,
		gn: float, grounded: bool, grip_scale: float, cap: float) -> void:
	# Step doubling cancels the leading error of the coupled force/axle/load
	# update. A full Euler trial and two half trials start from identical state;
	# only the accepted half-step path contributes clutch torque diagnostics.
	# Keep discrete shift events and bounded input controls from that path.
	var before := _integration_state()
	var matching := automatic_rev_match
	var min_torque := clutch_torque_min_nm
	var max_torque := clutch_torque_max_nm
	_integrate_euler(dt,gas,brake,steering_input,gx,gy,gn,grounded,grip_scale,cap,false)
	var coarse := _integration_state()
	_restore_integration_state(before)
	automatic_rev_match = matching
	clutch_torque_min_nm = min_torque
	clutch_torque_max_nm = max_torque
	_integrate_euler(dt*.5,gas,brake,steering_input,gx,gy,gn,grounded,grip_scale,cap,false)
	_integrate_euler(dt*.5,gas,brake,steering_input,gx,gy,gn,grounded,grip_scale,cap)
	var refined := _integration_state()
	var stopped := u == 0.0 and v == 0.0 and yaw_rate == 0.0
	# Steering, throttle, clutch and shift clock are rate-limited controls,
	# not unconstrained differential states. Extrapolating a control at its
	# target or a wheel at rest could overshoot the target or reverse a wheel.
	for index in [0,1,2,4,5,6,10,11,12,15]:
		if stopped and index in [0,1,2,4,5]: continue
		if index in [4,5] and refined[index] == 0.0: continue
		refined[index] = 2.0*refined[index]-coarse[index]
	_restore_integration_state(refined)
	engine_omega = maxf(p.idle_rpm*RPM_TO_RAD*.8,engine_omega) if engine_running else 0.0
	# Preserve hard assist/speed boundaries after extrapolation. Fractional
	# assists retain their existing intervention on the accepted half steps.
	var assist: float = p.assistance_strength if grounded else 0.0
	if assist*p.anti_lock_brakes >= 1.0 and brake > 0 and absf(u) > 1:
		var front_long: float = u*cos(steer)+(v+p.wheelbase_m*(1-p.front_weight_fraction)*yaw_rate)*sin(steer)
		var front_min: float = front_long*(1-p.braking_slip_limit)/p.front_radius_m
		var rear_min: float = u*(1-p.braking_slip_limit)/p.rear_radius_m
		if absf(front_omega) < absf(front_min): front_omega = front_min
		if absf(rear_omega) < absf(rear_min): rear_omega = rear_min
	if assist*p.traction_control >= 1.0 and gas > 0 and gear != 0:
		var direction := -1.0 if gear < 0 else 1.0
		var allowed: float = (maxf(0,u*direction)+p.traction_slip_limit*maxf(absf(u),p.slip_reference_speed_mps))/p.rear_radius_m
		if rear_omega*direction > allowed: rear_omega = allowed*direction
	var hard_cap: float = minf(cap,p.reverse_limit_kph/3.6) if gear == -1 else cap
	var speed := Vector2(u,v).length()
	if speed > hard_cap:
		u *= hard_cap/speed
		v *= hard_cap/speed

func _integration_state() -> PackedFloat64Array:
	# Include every evolving state read by the next force evaluation, plus the
	# heading accumulator. Force/load outputs are recomputed by each trial.
	return PackedFloat64Array([u,v,yaw_rate,steer,front_omega,rear_omega,engine_omega,
		throttle,clutch,shift_remaining,acceleration,load_transfer_acceleration,
		lateral_contact_acceleration,slipstream_strength,dirty_air_strength,heading_change])

func _restore_integration_state(state: PackedFloat64Array) -> void:
	u = state[0]
	v = state[1]
	yaw_rate = state[2]
	steer = state[3]
	front_omega = state[4]
	rear_omega = state[5]
	engine_omega = state[6]
	throttle = state[7]
	clutch = state[8]
	shift_remaining = state[9]
	acceleration = state[10]
	load_transfer_acceleration = state[11]
	lateral_contact_acceleration = state[12]
	slipstream_strength = state[13]
	dirty_air_strength = state[14]
	heading_change = state[15]

func _integrate_euler(dt: float, gas: float, brake: float, steering_input: float, gx: float, gy: float,
		gn: float, grounded: bool, grip_scale: float, cap: float, record_diagnostics := true) -> void:
	var tow_target := clampf(slipstream_target,0.0,1.0)
	var tow_time := Slipstream.BUILD_TIME_S if tow_target > slipstream_strength else Slipstream.RELEASE_TIME_S
	slipstream_strength = lerpf(slipstream_strength,tow_target,1.0-exp(-dt/tow_time))
	slipstream_drag_reduction = slipstream_strength*Slipstream.MAX_DRAG_REDUCTION
	var wake_target := clampf(dirty_air_target,0.0,1.0)
	var wake_time := Slipstream.BUILD_TIME_S if wake_target > dirty_air_strength else Slipstream.RELEASE_TIME_S
	dirty_air_strength = lerpf(dirty_air_strength,wake_target,1.0-exp(-dt/wake_time))
	var speed := Vector2(u,v).length()
	var air_velocity := Vector2(u,v)-wind_body_mps
	airspeed_mps = air_velocity.length()
	var lock := steering_lock_at_speed(speed)
	var assist: float = p.assistance_strength if grounded else 0.0
	var stability: float = assist*p.stability_assistance
	var traction: float = assist*p.traction_control
	var abs_assist: float = assist*p.anti_lock_brakes
	# Steering input scaling must not jump when road contact briefly drops out.
	# Airborne cars still have no tyre forces or yaw/sideslip stability intervention.
	var steering_assist: float = p.assistance_strength*p.steering_assistance
	var aero_load: float = .5*p.air_density_kg_m3*p.downforce_area_m2*airspeed_mps*airspeed_mps
	var front_aero_load: float = aero_load*p.front_downforce_fraction*(1.0-dirty_air_strength*Slipstream.MAX_FRONT_DOWNFORCE_LOSS)
	var rear_aero_load: float = aero_load*(1.0-p.front_downforce_fraction)*(1.0-dirty_air_strength*Slipstream.MAX_REAR_DOWNFORCE_LOSS)
	aero_load = front_aero_load+rear_aero_load
	# Turning the velocity around world up requires normal acceleration on a
	# banked road. For a level, constant-bank turn this is v²/R * sin(bank).
	# Use actual yaw, not requested steering, so steering alone cannot add load.
	var turn_normal_accel := yaw_rate*Vector2(u,v).dot(turn_normal_factors) if grounded else 0.0
	banking_load_n = vehicle_mass_kg*turn_normal_accel
	var support_accel := maxf(0.0,gn+turn_normal_accel)
	var tyre_lateral_accel: float = p.friction_coefficient*grip_scale*(support_accel+aero_load/vehicle_mass_kg)*p.corner_grip_fraction
	assisted_steering_lock_deg = lock
	var steering_rate: float = lerpf(p.steering_rate_deg_s,minf(p.steering_rate_deg_s,lock/p.steering_response_s),steering_assist)
	# Identical travel/rate in either direction, including countersteering.
	var target_steer := clampf(steering_input,-1,1)*deg_to_rad(lock)
	steer = target_steer if direct_steering else move_toward(steer,target_steer,deg_to_rad(steering_rate)*dt)
	var opening := clampf(gas,0,1) if engine_running else 0.0
	if is_finite(cap):
		opening *= clampf((cap-speed)/1.0,0,1)
	if rpm() >= p.redline_rpm or speed >= cap or (gear == -1 and speed >= p.reverse_limit_kph/3.6):
		opening = 0
	shift_remaining = maxf(0,shift_remaining-dt)
	if shift_remaining == 0:
		automatic_rev_match = false
	if shift_remaining > 0:
		opening = 0
	throttle = move_toward(throttle,opening,p.throttle_rate_s*dt)
	var ratio_value := ratio()
	var engagement: float = clampf((rpm()-p.idle_rpm)/(p.launch_rpm-p.idle_rpm),0,1)
	if absf(rear_omega*ratio_value) > p.idle_rpm*RPM_TO_RAD:
		engagement = 1
	if gear == 0 or shift_remaining > 0 or not engine_running:
		engagement = 0
	clutch = move_toward(clutch,engagement,p.clutch_engagement_rate_s*dt)
	var clutch_torque: float = clampf((engine_omega-rear_omega*ratio_value)*p.clutch_stiffness_nm_s,-p.clutch_capacity_nm*clutch,p.clutch_capacity_nm*clutch)
	clutch_torque_min_nm = minf(clutch_torque_min_nm,clutch_torque)
	clutch_torque_max_nm = maxf(clutch_torque_max_nm,clutch_torque)
	engine_opening = 0.0 if rpm() >= p.redline_rpm else throttle
	if automatic_rev_match and engine_running:
		# Blip only with the shift clutch open. Use available engine torque to
		# approach the new wheel-driven RPM, never teleport engine/axle speed or
		# remove the normal engine braking after the clutch reconnects.
		var target_omega: float = clampf(rear_omega*ratio_value,p.idle_rpm*RPM_TO_RAD,p.redline_rpm*RPM_TO_RAD)
		var closed_torque := torque_at(rpm(),0.0)
		var full_torque := torque_at(rpm(),1.0)
		var matching_torque: float = (target_omega-engine_omega)*p.inertia_kgm2/AUTO_REV_MATCH_RESPONSE_S
		var blip: float = clampf((matching_torque-closed_torque)/maxf(full_torque-closed_torque,.001),0.0,1.0)
		if rpm() < p.redline_rpm:
			engine_opening = maxf(engine_opening,blip)
	var engine_torque := torque_at(rpm(),engine_opening)
	engine_torque += clampf((p.idle_rpm*RPM_TO_RAD-engine_omega)*p.idle_control_gain,0,p.idle_control_max_nm)
	engine_omega = maxf(p.idle_rpm*RPM_TO_RAD*.8,engine_omega+(engine_torque-clutch_torque)/p.inertia_kgm2*dt)
	var drive_torque: float = clutch_torque*ratio_value*p.efficiency
	if not engine_running:
		engine_omega = 0.0
		clutch = 0.0
		throttle = 0.0
		drive_torque = 0.0
	var b: float = p.wheelbase_m*p.front_weight_fraction
	var a: float = p.wheelbase_m-b
	downforce_n = aero_load if grounded else 0.0
	front_downforce_n = front_aero_load if grounded else 0.0
	rear_downforce_n = rear_aero_load if grounded else 0.0
	drag_n = .5*p.air_density_kg_m3*p.drag_area_m2*airspeed_mps*airspeed_mps*(1.0-slipstream_drag_reduction)
	var weight: float = vehicle_mass_kg*support_accel if grounded else 0.0
	load_transfer_n = clampf(vehicle_mass_kg*load_transfer_acceleration*p.cg_height_m/p.wheelbase_m,-weight*.35,weight*.35)
	front_load = maxf(0,weight*p.front_weight_fraction+front_downforce_n-load_transfer_n)
	rear_load = maxf(0,weight*(1-p.front_weight_fraction)+rear_downforce_n+load_transfer_n)
	_update_wheel_loads()
	var front_lateral := v+a*yaw_rate
	var front_long := u*cos(steer)+front_lateral*sin(steer)
	var front_side := front_lateral*cos(steer)-u*sin(steer)
	front_slip_angle = atan2(front_side,maxf(absf(front_long),p.slip_reference_speed_mps))
	rear_slip_angle = atan2(v-b*yaw_rate,maxf(absf(u),p.slip_reference_speed_mps))
	front_slip_ratio = (front_omega*p.front_radius_m-front_long)/maxf(absf(front_long),p.slip_reference_speed_mps)
	rear_slip_ratio = (rear_omega*p.rear_radius_m-u)/maxf(absf(u),p.slip_reference_speed_mps)
	var front := _wheel_force(0,front_slip_ratio,front_slip_angle,p.front_cornering_stiffness_n_rad,grip_scale,record_diagnostics)+_wheel_force(1,front_slip_ratio,front_slip_angle,p.front_cornering_stiffness_n_rad,grip_scale,record_diagnostics)
	var rear := _wheel_force(2,rear_slip_ratio,rear_slip_angle,p.rear_cornering_stiffness_n_rad,grip_scale,record_diagnostics)+_wheel_force(3,rear_slip_ratio,rear_slip_angle,p.rear_cornering_stiffness_n_rad,grip_scale,record_diagnostics)
	if record_diagnostics:
		front_usage = front.length()/maxf(wheel_peaks[0]+wheel_peaks[1],.001)
		rear_usage = rear.length()/maxf(wheel_peaks[2]+wheel_peaks[3],.001)
	var front_brake: float = brake*p.brake_force_n*p.front_brake_bias*p.front_radius_m
	var rear_brake: float = brake*p.brake_force_n*(1-p.front_brake_bias)*p.rear_radius_m
	front_omega = move_toward(front_omega-front.x*p.front_radius_m/p.front_axle_inertia_kgm2*dt,0,front_brake/p.front_axle_inertia_kgm2*dt)
	rear_omega = move_toward(rear_omega+(drive_torque-rear.x*p.rear_radius_m)/p.rear_axle_inertia_kgm2*dt,0,rear_brake/p.rear_axle_inertia_kgm2*dt)
	# Accessibility assists deliberately intervene beyond the physical tyre model.
	# Limit driven wheelspin and prevent braking lock-up; also work in reverse.
	if assist > 0:
		if traction > 0 and gas > 0 and gear != 0:
			var direction_sign := -1.0 if gear < 0 else 1.0
			var allowed: float = (maxf(0,u*direction_sign)+p.traction_slip_limit*maxf(absf(u),p.slip_reference_speed_mps))/p.rear_radius_m
			if rear_omega*direction_sign > allowed:
				rear_omega = lerpf(rear_omega,allowed*direction_sign,traction)
		if abs_assist > 0 and brake > 0 and absf(u) > 1:
			var front_min: float = front_long*(1-p.braking_slip_limit)/p.front_radius_m
			var rear_min: float = u*(1-p.braking_slip_limit)/p.rear_radius_m
			if absf(front_omega) < absf(front_min):
				front_omega = lerpf(front_omega,front_min,abs_assist)
			if absf(rear_omega) < absf(rear_min):
				rear_omega = lerpf(rear_omega,rear_min,abs_assist)
	var front_x := front.x*cos(steer)-front.y*sin(steer)
	var front_y := front.x*sin(steer)+front.y*cos(steer)
	var rolling: float = p.rolling_resistance*(front_load+rear_load)
	var rolling_force := Vector2(u,v)/maxf(speed,.5)*rolling
	var resistance := air_velocity/maxf(airspeed_mps,.001)*drag_n+rolling_force
	var force_x := front_x+rear.x-resistance.x
	var force_y := front_y+rear.y-resistance.y
	var ax: float = force_x/vehicle_mass_kg+gx
	var old_u := u
	u += (ax+v*yaw_rate)*dt
	v += (force_y/vehicle_mass_kg+gy-old_u*yaw_rate)*dt
	yaw_rate += (a*front_y-b*rear.y)/vehicle_yaw_inertia_kgm2*dt
	if stability > 0:
		var requested_yaw: float = u*tan(steer)/p.wheelbase_m
		var yaw_cap: float = tyre_lateral_accel/maxf(absf(u),3)
		var gravity_yaw: float = gy*signf(u)/maxf(absf(u),3)
		requested_yaw = clampf(requested_yaw,minf(0.0,gravity_yaw-yaw_cap),maxf(0.0,gravity_yaw+yaw_cap))
		yaw_rate = lerpf(yaw_rate,requested_yaw,minf(1,dt*p.yaw_stability_rate_s*stability))
		v *= exp(-dt*p.sideslip_damping_rate_s*stability)
		# Stop a saturated rear axle from building into an uncontrolled spin.
		var permitted_error: float = .08+absf(requested_yaw)*.2
		yaw_rate = lerpf(yaw_rate,clampf(yaw_rate,requested_yaw-permitted_error,requested_yaw+permitted_error),stability)
	heading_change += yaw_rate*dt
	acceleration = lerpf(acceleration,ax,minf(1,dt*12))
	# Pitch equilibrium with drag applied at CG: transfer = contact Fx * h / L.
	# Engine braking, service braking and rolling resistance still unload the rear;
	# deceleration from aerodynamic drag or a road gradient does not do so by itself.
	var contact_accel: float = (front_x+rear.x-rolling_force.x)/vehicle_mass_kg
	load_transfer_acceleration = lerpf(load_transfer_acceleration,contact_accel,minf(1,dt*12))
	# Tyre/contact force supplies roll moment about the road plane. Gravity and
	# CG-applied aero do not: bank gravity already reduces the tyre force needed.
	var lateral_contact: float = (front_y+rear.y-rolling_force.y)/vehicle_mass_kg
	lateral_contact_acceleration = lerpf(lateral_contact_acceleration,lateral_contact,1.0-exp(-dt/p.roll_transfer_response_s)) if grounded else 0.0
	# Static low-speed settling avoids creep from the axle slip regularisation.
	if grounded and speed < .12 and gas == 0 and (brake > .05 or absf(gx)+absf(gy) < .05):
		u = 0
		v = 0
		yaw_rate = 0
		front_omega = 0
		rear_omega = 0
	var hard_cap: float = minf(cap,p.reverse_limit_kph/3.6) if gear == -1 else cap
	var planar_speed := Vector2(u,v).length()
	if planar_speed > hard_cap:
		u *= hard_cap/planar_speed
		v *= hard_cap/planar_speed

func _update_wheel_loads() -> void:
	# Positive leftward contact force transfers load to the right tyres.
	# This quasi-static roll model has no suspension travel or rollover dynamics.
	var moment: float = vehicle_mass_kg*lateral_contact_acceleration*p.cg_height_m
	front_lateral_transfer_n = clampf(moment*p.front_roll_stiffness_fraction/p.front_track_m,-front_load*.5,front_load*.5)
	rear_lateral_transfer_n = clampf(moment*(1.0-p.front_roll_stiffness_fraction)/p.rear_track_m,-rear_load*.5,rear_load*.5)
	wheel_loads[0] = front_load*.5-front_lateral_transfer_n
	wheel_loads[1] = front_load*.5+front_lateral_transfer_n
	wheel_loads[2] = rear_load*.5-rear_lateral_transfer_n
	wheel_loads[3] = rear_load*.5+rear_lateral_transfer_n

func _peak_force(load_n: float, grip: float) -> float:
	# Bound the friction coefficient near zero load while keeping force continuous.
	var load_ratio: float = maxf(load_n/p.reference_load_n,.1)
	return maxf(0,load_n)*p.friction_coefficient*maxf(0,grip)*pow(load_ratio,p.load_grip_exponent-1.0)

func _wheel_force(index: int, slip: float, angle: float, axle_stiffness: float, grip: float, record_diagnostics := true) -> Vector2:
	# Twice the individual load uses the existing axle reference; half the force
	# preserves the original stiffness/force at equal loads when exponent = 1.
	var equivalent_load := 2.0*wheel_loads[index]
	var force := .5*_tyre(equivalent_load,slip,angle,axle_stiffness,grip)
	# Only the accepted endpoint needs HUD/telemetry values. Trial stages still
	# evaluate identical physical forces without repeated diagnostic arithmetic.
	if not record_diagnostics: return force
	var peak := .5*_peak_force(equivalent_load,grip)
	wheel_peaks[index] = peak
	wheel_usage[index] = force.length()/maxf(peak,.001)
	var raw := .5*pow(equivalent_load/p.reference_load_n,p.load_stiffness_exponent)*Vector2(p.longitudinal_stiffness_n*slip,-axle_stiffness*angle)
	# 1.0 is the peak of the tyre curve; >1 still flags sliding when force falls.
	wheel_demand[index] = raw.length()/maxf(peak*PI/2.0,.001) if peak > 0 else 0.0
	return force

func _tyre(load_n: float, slip: float, angle: float, stiffness: float, grip: float) -> Vector2:
	if load_n <= 0 or grip <= 0:
		return Vector2.ZERO
	var load_scale: float = pow(load_n/p.reference_load_n,p.load_stiffness_exponent)
	var force := Vector2(p.longitudinal_stiffness_n*load_scale*slip,-stiffness*load_scale*angle)
	var demand := force.length()
	if demand < .000001:
		return Vector2.ZERO
	var peak := _peak_force(load_n,grip)
	var normalized := demand/peak
	# Preserve small-slip stiffness, with a smooth peak at normalized demand PI/2.
	# Both components share this envelope, so wheelspin/braking uses cornering grip.
	var magnitude := sin(minf(normalized,PI/2.0))
	if normalized > PI/2.0:
		var excess: float = (normalized-PI/2.0)/p.post_peak_falloff
		magnitude = p.sliding_grip_fraction+(1.0-p.sliding_grip_fraction)*exp(-excess*excess)
	return force/demand*(peak*magnitude)
