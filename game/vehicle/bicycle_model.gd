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
var front_omega := 0.0
var rear_omega := 0.0
var engine_omega := 0.0
var engine_running := true
var throttle := 0.0
var gear := 1
var automatic := true
var shift_remaining := 0.0
var clutch := 0.0
var acceleration := 0.0
var front_slip_angle := 0.0
var rear_slip_angle := 0.0
var front_slip_ratio := 0.0
var rear_slip_ratio := 0.0
var front_usage := 0.0
var rear_usage := 0.0
var front_load := 0.0
var rear_load := 0.0
var drag_n := 0.0
var downforce_n := 0.0
var heading_change := 0.0
const RPM_TO_RAD := TAU/60.0

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
	front_omega = 0
	rear_omega = 0
	engine_omega = p.idle_rpm*RPM_TO_RAD if engine_running else 0.0
	throttle = 0
	gear = 1
	shift_remaining = 0
	clutch = 0
	acceleration = 0
	heading_change = 0
	front_usage = 0
	rear_usage = 0

func rpm() -> float:
	return engine_omega/RPM_TO_RAD

func set_engine_running(value: bool) -> void:
	engine_running = value
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
		if rpm() > p.automatic_upshift_rpm and gear < 6 and absf(rear_slip_ratio) < .20:
			select_gear(gear+1)
		elif rpm() < p.automatic_downshift_rpm and gear > 1:
			select_gear(gear-1)
	# Small fixed upper bound avoids low-speed slip stiffness instability.
	var steps := maxi(1,int(ceil(delta/.001)))
	var dt := delta/steps
	for unused in range(steps):
		_integrate(dt,gas,brake,steering_input,gravity_forward,gravity_left,normal_gravity,grounded,grip_scale,speed_cap_mps)

func _integrate(dt: float, gas: float, brake: float, steering_input: float, gx: float, gy: float,
		gn: float, grounded: bool, grip_scale: float, cap: float) -> void:
	var speed := Vector2(u,v).length()
	var lock: float = lerpf(p.steering_lock_deg,p.high_speed_lock_deg,clampf(speed/p.steering_reduction_speed_mps,0,1))
	var assist: float = p.assistance_strength if grounded else 0.0
	# Steering input scaling must not jump when road contact briefly drops out.
	# Airborne cars still have no tyre forces or yaw/sideslip stability intervention.
	var steering_assist: float = p.assistance_strength
	var aero_load: float = .5*p.air_density_kg_m3*p.downforce_area_m2*speed*speed
	var safe_lateral_accel: float = p.friction_coefficient*grip_scale*(gn+aero_load/vehicle_mass_kg)*p.corner_grip_fraction
	var safe_lock := rad_to_deg(atan(p.wheelbase_m*safe_lateral_accel/maxf(speed*speed,1)))
	# Geometric steering alone omits the extra angle needed for tyre slip.
	safe_lock *= p.steering_range_multiplier
	lock = lerpf(lock,minf(lock,safe_lock),steering_assist)
	var steering_rate: float = lerpf(p.steering_rate_deg_s,minf(p.steering_rate_deg_s,lock/p.steering_response_s),steering_assist)
	steer = move_toward(steer,clampf(steering_input,-1,1)*deg_to_rad(lock),deg_to_rad(steering_rate)*dt)
	var opening := clampf(gas,0,1) if engine_running else 0.0
	if is_finite(cap):
		opening *= clampf((cap-speed)/1.0,0,1)
	if rpm() >= p.redline_rpm or speed >= cap or (gear == -1 and speed >= p.reverse_limit_kph/3.6):
		opening = 0
	shift_remaining = maxf(0,shift_remaining-dt)
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
	var engine_torque := torque_at(rpm(),0.0 if rpm() >= p.redline_rpm else throttle)
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
	downforce_n = .5*p.air_density_kg_m3*p.downforce_area_m2*speed*speed if grounded else 0.0
	drag_n = .5*p.air_density_kg_m3*p.drag_area_m2*speed*speed
	var weight: float = vehicle_mass_kg*gn if grounded else 0.0
	var transfer: float = clampf(vehicle_mass_kg*acceleration*p.cg_height_m/p.wheelbase_m,-weight*.35,weight*.35)
	front_load = maxf(0,weight*p.front_weight_fraction+downforce_n*p.front_downforce_fraction-transfer)
	rear_load = maxf(0,weight*(1-p.front_weight_fraction)+downforce_n*(1-p.front_downforce_fraction)+transfer)
	var front_lateral := v+a*yaw_rate
	var front_long := u*cos(steer)+front_lateral*sin(steer)
	var front_side := front_lateral*cos(steer)-u*sin(steer)
	front_slip_angle = atan2(front_side,maxf(absf(front_long),p.slip_reference_speed_mps))
	rear_slip_angle = atan2(v-b*yaw_rate,maxf(absf(u),p.slip_reference_speed_mps))
	front_slip_ratio = (front_omega*p.front_radius_m-front_long)/maxf(absf(front_long),p.slip_reference_speed_mps)
	rear_slip_ratio = (rear_omega*p.rear_radius_m-u)/maxf(absf(u),p.slip_reference_speed_mps)
	var front := _tyre(front_load,front_slip_ratio,front_slip_angle,p.front_cornering_stiffness_n_rad,grip_scale)
	var rear := _tyre(rear_load,rear_slip_ratio,rear_slip_angle,p.rear_cornering_stiffness_n_rad,grip_scale)
	front_usage = front.length()/maxf(front_load*p.friction_coefficient*grip_scale,.001)
	rear_usage = rear.length()/maxf(rear_load*p.friction_coefficient*grip_scale,.001)
	var front_brake: float = brake*p.brake_force_n*p.front_brake_bias*p.front_radius_m
	var rear_brake: float = brake*p.brake_force_n*(1-p.front_brake_bias)*p.rear_radius_m
	front_omega = move_toward(front_omega-front.x*p.front_radius_m/p.front_axle_inertia_kgm2*dt,0,front_brake/p.front_axle_inertia_kgm2*dt)
	rear_omega = move_toward(rear_omega+(drive_torque-rear.x*p.rear_radius_m)/p.rear_axle_inertia_kgm2*dt,0,rear_brake/p.rear_axle_inertia_kgm2*dt)
	# Accessibility assists deliberately intervene beyond the physical tyre model.
	# Limit driven wheelspin and prevent braking lock-up; also work in reverse.
	if assist > 0:
		if gas > 0 and gear != 0:
			var direction_sign := -1.0 if gear < 0 else 1.0
			var allowed: float = (maxf(0,u*direction_sign)+p.traction_slip_limit*maxf(absf(u),p.slip_reference_speed_mps))/p.rear_radius_m
			if rear_omega*direction_sign > allowed:
				rear_omega = lerpf(rear_omega,allowed*direction_sign,assist)
		if brake > 0 and absf(u) > 1:
			var front_min: float = front_long*(1-p.braking_slip_limit)/p.front_radius_m
			var rear_min: float = u*(1-p.braking_slip_limit)/p.rear_radius_m
			if absf(front_omega) < absf(front_min):
				front_omega = lerpf(front_omega,front_min,assist)
			if absf(rear_omega) < absf(rear_min):
				rear_omega = lerpf(rear_omega,rear_min,assist)
	var front_x := front.x*cos(steer)-front.y*sin(steer)
	var front_y := front.x*sin(steer)+front.y*cos(steer)
	var rolling: float = p.rolling_resistance*(front_load+rear_load)
	var resistance := Vector2(u,v)/maxf(speed,.5)*(drag_n+rolling)
	var force_x := front_x+rear.x-resistance.x
	var force_y := front_y+rear.y-resistance.y
	var ax: float = force_x/vehicle_mass_kg+gx
	var old_u := u
	u += (ax+v*yaw_rate)*dt
	v += (force_y/vehicle_mass_kg+gy-old_u*yaw_rate)*dt
	yaw_rate += (a*front_y-b*rear.y)/vehicle_yaw_inertia_kgm2*dt
	if assist > 0:
		var requested_yaw: float = u*tan(steer)/p.wheelbase_m
		var yaw_cap: float = safe_lateral_accel/maxf(absf(u),3)
		requested_yaw = clampf(requested_yaw,-yaw_cap,yaw_cap)
		yaw_rate = lerpf(yaw_rate,requested_yaw,minf(1,dt*p.yaw_stability_rate_s*assist))
		v *= exp(-dt*p.sideslip_damping_rate_s*assist)
		# Stop a saturated rear axle from building into an uncontrolled spin.
		var permitted_error: float = .08+absf(requested_yaw)*.2
		yaw_rate = lerpf(yaw_rate,clampf(yaw_rate,requested_yaw-permitted_error,requested_yaw+permitted_error),assist)
	heading_change += yaw_rate*dt
	acceleration = lerpf(acceleration,ax,minf(1,dt*12))
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

func _tyre(load_n: float, slip: float, angle: float, stiffness: float, grip: float) -> Vector2:
	if load_n <= 0:
		return Vector2.ZERO
	var load_scale: float = pow(load_n/p.reference_load_n,p.load_stiffness_exponent)
	var force := Vector2(p.longitudinal_stiffness_n*load_scale*slip,-stiffness*load_scale*angle)
	return force.limit_length(load_n*p.friction_coefficient*grip)
