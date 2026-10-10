extends "res://game/vehicle/body_suspension.gd"
## Sprung-body heave/roll/pitch with unilateral road contacts. No unsprung mass.
## Four positive corner springs plus heave and anti-roll/pitch coupling springs
## preserve the authored modal stiffnesses without counting transfer twice.
var wheel_travel_enabled := false
var sampled := false
var initialized := false
var ride_height_m := .16
var heave_stiffness_n_m := 400000.0
var pitch_stiffness_scale := 1.0
var roll_stiffness_scale := 1.0
var bump_travel_m := .08
var rebound_travel_m := .08
var bump_stop_stiffness_n_m := 1000000.0
var heave_velocity_mps := 0.0
var heave_delta_m := 0.0
var sample_time_s := 0.0
var road_roll_rate := 0.0
var road_pitch_rate := 0.0
var gaps := PackedFloat64Array([0.0,0.0,0.0,0.0])
var road_velocity := PackedFloat64Array([0.0,0.0,0.0,0.0])
var road_present := PackedByteArray([0,0,0,0])
var compression := PackedFloat64Array([0.0,0.0,0.0,0.0])
var compression_rate := PackedFloat64Array([0.0,0.0,0.0,0.0])
var loads := PackedFloat64Array([0.0,0.0,0.0,0.0])
var bump_stop_loads := PackedFloat64Array([0.0,0.0,0.0,0.0])
var contact := PackedByteArray([0,0,0,0])

func reset() -> void:
	super.reset()
	sampled = false
	initialized = false
	heave_velocity_mps = 0.0
	heave_delta_m = 0.0
	sample_time_s = 0.0
	road_roll_rate = 0.0
	road_pitch_rate = 0.0
	compression.fill(0.0)
	compression_rate.fill(0.0)
	loads.fill(0.0)
	bump_stop_loads.fill(0.0)
	contact.fill(0)

func configure_indy(path: String) -> bool:
	if not super.configure_indy(path):
		return false
	var cfg := ConfigFile.new()
	cfg.load(path)
	for key in ["ride_height_m","heave_stiffness_n_m","pitch_stiffness_scale","roll_stiffness_scale","bump_travel_m","rebound_travel_m","bump_stop_stiffness_n_m"]:
		var value = cfg.get_value("travel",key,null)
		if not (value is float or value is int) or not is_finite(float(value)) or value <= 0:
			enabled = false
			return false
		set(key,float(value))
	if bump_travel_m >= ride_height_m:
		enabled = false
		return false
	wheel_travel_enabled = true
	profile_id = "indy_four_contact_suspension_v6"
	return true

func travel_active() -> bool:
	return enabled and wheel_travel_enabled and sampled

func begin_frame(corner_gaps: PackedFloat64Array, corner_velocity: PackedFloat64Array, present: PackedByteArray) -> void:
	gaps = corner_gaps.duplicate()
	road_velocity = corner_velocity.duplicate()
	road_present = present.duplicate()
	heave_delta_m = 0.0
	sample_time_s = 0.0
	sampled = true

func has_support() -> bool:
	for i in range(4):
		if road_present[i] and gaps[i] <= ride_height_m+rebound_travel_m:
			return true
	return false

func advance_travel(dt: float, mass: float, p: Dictionary, normal_gravity: float,
		support_accel: float, front_aero: float, rear_aero: float,
		roll_input: float, pitch_input: float) -> void:
	var f: float = p.front_weight_fraction
	var a: float = p.wheelbase_m*(1.0-f)
	var b: float = p.wheelbase_m*f
	var xs := PackedFloat64Array([a,a,-b,-b])
	var ys := PackedFloat64Array([p.front_track_m*.5,-p.front_track_m*.5,p.rear_track_m*.5,-p.rear_track_m*.5])
	var weights := PackedFloat64Array([f*.5,f*.5,(1.0-f)*.5,(1.0-f)*.5])
	var vx := a*b
	var vy: float = f*pow(p.front_track_m*.5,2)+(1.0-f)*pow(p.rear_track_m*.5,2)
	var ir: float = roll_inertia_kgm2*roll_stiffness_scale*mass/p.mass_kg
	var ip: float = pitch_inertia_kgm2*mass/p.mass_kg
	var ch := 2.0*damping_ratio*sqrt(heave_stiffness_n_m*mass)
	var roll_k := roll_stiffness_nm_rad*roll_stiffness_scale
	var cr := 2.0*damping_ratio*sqrt(roll_k*ir)
	var pitch_k := pitch_stiffness_nm_rad*pitch_stiffness_scale
	var cp := 2.0*damping_ratio*sqrt(pitch_k*ip)
	# Reserve positive stiffness/damping for all modal coupling springs. Both
	# axle anti-roll contributions remain nonnegative at every allowed balance.
	var front_roll_k: float = roll_k*p.front_roll_stiffness_fraction
	var rear_roll_k: float = roll_k-front_roll_k
	var front_roll_c: float = cr*p.front_roll_stiffness_fraction
	var rear_roll_c: float = cr-front_roll_c
	var base_k := .8*minf(heave_stiffness_n_m,minf(pitch_k/vx,
		minf(front_roll_k/(f*pow(ys[0],2)),rear_roll_k/((1-f)*pow(ys[2],2)))))
	var base_c := .8*minf(ch,minf(cp/vx,minf(front_roll_c/(f*pow(ys[0],2)),rear_roll_c/((1-f)*pow(ys[2],2)))))
	var mean_c := 0.0
	var mean_rate := 0.0
	var pitch_c := 0.0
	var pitch_speed := 0.0
	var roll_c := 0.0
	var roll_speed := 0.0
	for i in range(4):
		compression[i] = ride_height_m-gaps[i]+road_velocity[i]*sample_time_s-heave_delta_m-xs[i]*pitch-ys[i]*roll
		# Changing road coordinates rotates both the gap and relative body angle.
		# Those frame-rate terms cancel in physical spring travel. Road-point
		# velocity already carries the bump input; adding frame rate again
		# creates a second damper impulse and disturbs axle balance.
		compression_rate[i] = road_velocity[i]-heave_velocity_mps-xs[i]*pitch_rate-ys[i]*roll_rate
		mean_c += weights[i]*compression[i]
		mean_rate += weights[i]*compression_rate[i]
		pitch_c += weights[i]*xs[i]*compression[i]/vx
		pitch_speed += weights[i]*xs[i]*compression_rate[i]/vx
		roll_c += weights[i]*ys[i]*compression[i]/vy
		roll_speed += weights[i]*ys[i]*compression_rate[i]/vy
	var total := 0.0
	var roll_support := 0.0
	var pitch_support := 0.0
	for i in range(4):
		var spring := mass*normal_gravity*weights[i]+weights[i]*(base_k*compression[i]+base_c*compression_rate[i])
		spring += weights[i]*((heave_stiffness_n_m-base_k)*mean_c+(ch-base_c)*mean_rate)
		spring += weights[i]*xs[i]/vx*((pitch_k-base_k*vx)*pitch_c+(cp-base_c*vx)*pitch_speed)
		var axle_weight: float = f if i < 2 else 1.0-f
		var axle_k: float = front_roll_k if i < 2 else rear_roll_k
		var axle_c: float = front_roll_c if i < 2 else rear_roll_c
		spring += weights[i]*ys[i]/(axle_weight*ys[i]*ys[i])*((axle_k-base_k*axle_weight*ys[i]*ys[i])*roll_c+(axle_c-base_c*axle_weight*ys[i]*ys[i])*roll_speed)
		bump_stop_loads[i] = bump_stop_stiffness_n_m*maxf(0.0,compression[i]-bump_travel_m)
		# A wheel beyond droop or with no road cannot exert force. A damper
		# cannot pull the road upwards; all delivered normal loads are unilateral.
		contact[i] = int(road_present[i] and compression[i] >= -rebound_travel_m and spring+bump_stop_loads[i] > 0)
		loads[i] = maxf(0.0,spring+bump_stop_loads[i]) if contact[i] else 0.0
		if not contact[i]: bump_stop_loads[i] = 0.0
		total += loads[i]
		roll_support += loads[i]*ys[i]
		pitch_support += loads[i]*xs[i]
	heave_velocity_mps += (total-mass*support_accel-front_aero-rear_aero)/mass*dt
	heave_delta_m += heave_velocity_mps*dt
	roll_rate += (roll_input+roll_support)/ir*dt
	# Aero axle loading is an external pitch moment, so the spring reaction
	# reproduces authored front/rear downforce distribution at equilibrium.
	pitch_rate += (pitch_input+pitch_support-front_aero*a+rear_aero*b)/ip*dt
	roll += roll_rate*dt
	pitch += pitch_rate*dt
	roll_reaction_nm = -roll_support
	pitch_reaction_nm = -pitch_support+front_aero*a-rear_aero*b
	sample_time_s += dt

func metadata() -> Dictionary:
	var result := super.metadata()
	result.merge({"wheel_travel_enabled":wheel_travel_enabled,"ride_height_m":ride_height_m,
		"heave_stiffness_n_m":heave_stiffness_n_m,"bump_travel_m":bump_travel_m,
		"travel_pitch_stiffness_nm_rad":pitch_stiffness_nm_rad*pitch_stiffness_scale,
		"travel_roll_stiffness_nm_rad":roll_stiffness_nm_rad*roll_stiffness_scale,
		"travel_roll_inertia_kgm2":roll_inertia_kgm2*roll_stiffness_scale,
		"rebound_travel_m":rebound_travel_m,"bump_stop_stiffness_n_m":bump_stop_stiffness_n_m,
		"unsprung_mass_modelled":false,"road_aligned_collision_backstop":enabled and wheel_travel_enabled})
	result.merge({"road_frame_sampling":"four_contact_height_fit","parent_yaw_transport":true,
		"damper_frame_rotation_counted":false,"banking_load_model":"road_normal_motion"})
	return result
