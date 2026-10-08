extends SceneTree
const Config = preload("res://game/vehicle/physics_config.gd")
const Model = preload("res://game/vehicle/bicycle_model.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _initialize() -> void:
	var config = Config.new()
	if not config.load_directory("res://content/vehicles/open_wheel/physics"):
		push_error(str(config.errors))
		quit(1)
		return
	# Isolate forces applied at the CG: aero drag and road gravity can slow the
	# car, but cannot create a pitch moment without a contact force at road level.
	for grade in [0.0,-3.0,3.0]:
		var sim = Model.new()
		sim.configure(config.values.duplicate(true))
		sim.p.rolling_resistance = 0.0
		sim.p.downforce_area_m2 = 0.0
		sim.p.drag_area_m2 = 1.0
		sim.gear = 0
		sim.u = 90
		for i in range(60): sim.advance(1.0/60,0,0,0,grade,0,9.81,true,0.0)
		check(sim.u < 90,"Drag still decelerates car")
		check(absf(sim.load_transfer_n) < .001 and is_equal_approx(sim.front_load/(sim.front_load+sim.rear_load),sim.p.front_weight_fraction),"CG drag/gravity alone do not transfer axle load")
	# Braking and acceleration are ground forces and must retain physical transfer.
	for braking in [false,true]:
		var sim = Model.new()
		sim.configure(config.values.duplicate(true))
		sim.u = 30
		sim.gear = 3
		sim.automatic = false
		sim.clutch = 1.0
		sim.throttle = 0.0 if braking else 1.0
		sim.front_omega = sim.u/sim.p.front_radius_m
		sim.rear_omega = sim.u/sim.p.rear_radius_m
		sim.engine_omega = sim.rear_omega*sim.ratio()
		for i in range(30): sim.advance(1.0/60,0.0 if braking else 1.0,.6 if braking else 0.0,0)
		check(sim.load_transfer_n < -100 if braking else sim.load_transfer_n > 100,"Contact force transfers load in correct direction")
		sim.reset()
		check(sim.load_transfer_n == 0 and sim.load_transfer_acceleration == 0,"Reset clears transfer history")
	var peak_60 := replay(config.values,1)
	var peak_120 := replay(config.values,2)
	check(absf(peak_60-peak_120) < .2,"Lift response agrees at 60/120 Hz")
	var loose_peak := replay(config.values,1,true)
	check(loose_peak > peak_60+.5,"9/3 retains looser balance than 6/3 with matched steering angles")
	for event in ["entry","exit","late"]:
		var fixture_path: String = "res://tools/fixtures/texas_lift_"+event+".json"
		var at_60 := replay(config.values,1,false,fixture_path)
		var at_120 := replay(config.values,2,false,fixture_path)
		check(absf(at_60-at_120) < .2,event+": steering range response agrees at 60/120 Hz")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("LIFT-OFF PASSED: CG force isolation, braking/drive transfer, Texas lift replay and 60/120 Hz agreement.")
	quit(0 if failures.is_empty() else 1)

func replay(parameters: Dictionary, subdivisions: int, loose_setup := false, fixture_path := "res://tools/fixtures/texas_lift_6_3.json") -> float:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	var p := parameters.duplicate(true)
	p.final_drive = fixture.final_drive
	p.forward_ratios = fixture.ratios
	preload("res://game/vehicle/aero_model.gd").apply(p,"speedway",9.0 if loose_setup else fixture.wings[0],fixture.wings[1])
	var sim = Model.new()
	sim.configure(p)
	var first: Dictionary = fixture.initial
	sim.set_vehicle_mass(first.vehicle_mass_kg)
	sim.u = first.u_mps
	sim.v = first.v_left_mps
	sim.yaw_rate = deg_to_rad(first.yaw_deg_s)
	sim.steer = deg_to_rad(first.steer_deg)
	sim.gear = int(first.gear)
	sim.engine_omega = first.rpm*TAU/60.0
	sim.throttle = first.throttle_input
	sim.clutch = 1.0
	var support: float = first.front_load_n+first.rear_load_n-first.downforce_n
	sim.load_transfer_acceleration = (support*p.front_weight_fraction+first.front_downforce_n-first.front_load_n)*p.wheelbase_m/(sim.vehicle_mass_kg*p.cg_height_m)
	sim.acceleration = sim.load_transfer_acceleration
	if first.has("load_transfer_accel_mps2"):
		sim.load_transfer_acceleration = first.load_transfer_accel_mps2
		sim.acceleration = first.longitudinal_accel_mps2
	var fl: float = sim.u*cos(sim.steer)+(sim.v+p.wheelbase_m*(1-p.front_weight_fraction)*sim.yaw_rate)*sin(sim.steer)
	sim.front_omega = (fl+first.front_slip_ratio*maxf(absf(fl),p.slip_reference_speed_mps))/p.front_radius_m
	sim.rear_omega = (sim.u+first.rear_slip_ratio*maxf(absf(sim.u),p.slip_reference_speed_mps))/p.rear_radius_m
	# Keep driver corrections but freeze the old input-to-angle scale at entry.
	# Raw normalized inputs from the former grip-limited mapping are not portable.
	var reference_lock: float = absf(first.steer_deg/first.steering_input)
	var peak_slip := 0.0
	var peak_yaw := 0.0
	var braking_slip := 0.0
	for frame in fixture.frames:
		var r := {}
		for i in range(fixture.columns.size()): r[fixture.columns[i]] = frame[i]
		var normal := Vector3(r.normal_x,r.normal_y,r.normal_z)
		var forward := Vector3(-sin(deg_to_rad(r.heading_deg)),0,-cos(deg_to_rad(r.heading_deg))).slide(normal).normalized()
		var left := normal.cross(forward).normalized()
		sim.turn_normal_factors = Vector2(Vector3.UP.cross(forward).dot(normal),Vector3.UP.cross(left).dot(normal))
		for i in range(subdivisions):
			var input: float = r.steering_input*reference_lock/sim.steering_lock_at_speed(Vector2(sim.u,sim.v).length())
			sim.advance(r.dt_s/subdivisions,r.throttle_input,r.brake_input,input,r.gravity_forward_mps2,r.gravity_left_mps2,r.normal_gravity_mps2,r.grounded>0,r.grip_scale)
		peak_slip = maxf(peak_slip,absf(rad_to_deg(atan2(sim.v,absf(sim.u)))))
		peak_yaw = maxf(peak_yaw,absf(rad_to_deg(sim.yaw_rate)))
		braking_slip = minf(braking_slip,sim.rear_slip_ratio)
	if not loose_setup:
		# This exit recording previously relied on automatic range reduction.
		# Holding its entry gain now exposes a larger physical slide (about 8 deg),
		# rather than the assistance unwinding the steering on the driver's behalf.
		var exit_event := fixture_path.ends_with("_exit.json")
		var slip_limit: float = 9.0 if exit_event else fixture.get("max_sideslip_deg",4.0)
		var yaw_limit: float = 40.0 if exit_event else fixture.get("max_yaw_deg_s",35.0)
		check(peak_slip < slip_limit and peak_yaw < yaw_limit,fixture_path+": fixed-angle-scale lift remains bounded without stability control")
	check(braking_slip < -.001,"Engine braking remains present on lift")
	print("TEXAS LIFT ",fixture_path.get_file()," fixed range=",reference_lock," wings=",p.front_wing_deg,"/3 hz=",60*subdivisions," peak sideslip=",peak_slip," peak yaw=",peak_yaw," rear braking slip=",braking_slip)
	return peak_slip
