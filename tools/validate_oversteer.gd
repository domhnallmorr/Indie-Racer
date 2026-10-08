extends SceneTree
const Config = preload("res://game/vehicle/physics_config.gd")
const Model = preload("res://game/vehicle/bicycle_model.gd")
const DT := 1.0/60.0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func moving(parameters: Dictionary, speed := 25.0):
	var sim = Model.new()
	sim.configure(parameters.duplicate(true))
	sim.u = speed
	sim.gear = 2
	sim.front_omega = speed/sim.p.front_radius_m
	sim.rear_omega = speed/sim.p.rear_radius_m
	sim.engine_omega = sim.rear_omega*sim.ratio()
	return sim

func steering_input(sim, angle_deg: float) -> float:
	return angle_deg/sim.steering_lock_at_speed(Vector2(sim.u,sim.v).length())

func beta(sim) -> float:
	return rad_to_deg(atan2(sim.v,absf(sim.u)))

func _initialize() -> void:
	var config = Config.new()
	check(config.load_directory("res://content/vehicles/open_wheel/physics"),"Valid physics configuration")
	if not failures.is_empty():
		quit(1)
		return
	var p: Dictionary = config.values
	var tyre = Model.new()
	tyre.configure(p.duplicate(true))
	var load_n: float = p.reference_load_n
	var peak: float = load_n*p.friction_coefficient
	var stiffness: float = p.rear_cornering_stiffness_n_rad
	var peak_angle: float = (PI/2.0)*peak/stiffness
	check(is_equal_approx(tyre._tyre(load_n,0,.00001,stiffness,1).y/-.00001,stiffness),"Small-slip cornering stiffness preserved")
	check(is_equal_approx(tyre._tyre(load_n,0,peak_angle,stiffness,1).length(),peak),"Tyre reaches peak grip")
	check(tyre._tyre(load_n,0,peak_angle*2,stiffness,1).length() < peak*.99,"Post-peak force falls")
	check(is_equal_approx(tyre._tyre(load_n,0,peak_angle*20,stiffness,1).length(),peak*p.sliding_grip_fraction),"Large slip retains configured sliding grip")
	check(tyre._tyre(0,1,1,stiffness,1) == Vector2.ZERO and tyre._tyre(load_n,1,1,stiffness,0) == Vector2.ZERO,"No load/grip produces no force")
	var below: Vector2 = tyre._tyre(load_n,0,peak_angle-.000001,stiffness,1)
	var above: Vector2 = tyre._tyre(load_n,0,peak_angle+.000001,stiffness,1)
	check(below.distance_to(above) < .001,"Continuous peak transition")
	for slip in [0.0,.03,.1,.5,2.0]:
		for angle in [.01,.06,.2,.8]:
			var force: Vector2 = tyre._tyre(load_n,slip,angle,stiffness,1)
			check(force.length() <= peak+.001,"Combined slip respects force budget")
			check(force.is_equal_approx(-tyre._tyre(load_n,-slip,-angle,stiffness,1)),"Tyre force sign symmetry")
	check(absf(tyre._tyre(load_n,.3,.06,stiffness,1).y) < absf(tyre._tyre(load_n,0,.06,stiffness,1).y),"Wheelspin reduces lateral support")
	# Master-off and all independent assists off must be exactly equivalent.
	var master_off = moving(p)
	var separate_off = moving(p)
	master_off.p.assistance_strength = 0.0
	for key in Config.ASSIST_STRENGTHS:
		if key != "assistance_strength": separate_off.p[key] = 0.0
	for i in range(120):
		master_off.advance(DT,.7,.1,.2)
		separate_off.advance(DT,.7,.1,.2)
	check(is_equal_approx(master_off.v,separate_off.v) and is_equal_approx(master_off.yaw_rate,separate_off.yaw_rate),"Independent assist switches preserve master-off behaviour")
	# Power-on breakaway and an early driver catch, mirrored in both directions.
	# Command road-wheel degrees so a steering-assist change cannot silently
	# turn this into a different corner. The old normalized .3 is not portable.
	for direction in [-1.0,1.0]:
		var caught = moving(p)
		var held = moving(p)
		for i in range(60):
			caught.advance(DT,.2,0,steering_input(caught,2.0*direction))
			held.advance(DT,.2,0,steering_input(held,2.0*direction))
		check(absf(beta(caught)) < 1.0,"Steady part-throttle corner remains composed")
		var onset := false
		for i in range(120):
			caught.advance(DT,1,0,steering_input(caught,2.0*direction))
			held.advance(DT,1,0,steering_input(held,2.0*direction))
			if beta(caught)*direction < -2.0:
				onset = true
				break
		check(onset and absf(caught.rear_slip_angle) > absf(caught.front_slip_angle),"Power produces rear-led breakaway")
		var peak_caught := 0.0
		var peak_held := 0.0
		for i in range(180):
			caught.advance(DT,0,0,steering_input(caught,-3.0*direction) if i < 60 else 0.0)
			held.advance(DT,1,0,steering_input(held,2.0*direction))
			peak_caught = maxf(peak_caught,absf(beta(caught)))
			peak_held = maxf(peak_held,absf(beta(held)))
		check(peak_caught < 8 and absf(beta(caught)) < 1 and absf(caught.yaw_rate) < .05 and caught.u > 10,"Early lift/countersteer catches slide without reversing")
		check(peak_held > 30,"Holding throttle/steering can produce a spin")
		print("OVERSTEER direction=",direction," caught peak=",peak_caught," held peak=",peak_held)
	var traction_on = moving(p)
	var traction_off = moving(p)
	traction_on.p.traction_control = 1.0
	for i in range(60):
		traction_on.advance(DT,1,0,steering_input(traction_on,2.0))
		traction_off.advance(DT,1,0,steering_input(traction_off,2.0))
	check(absf(traction_on.rear_slip_ratio) < .1 and traction_off.rear_slip_ratio > .2,"Traction control independently limits wheelspin")
	var abs_on = moving(p)
	var abs_off = moving(p)
	abs_off.p.anti_lock_brakes = 0.0
	for i in range(30):
		abs_on.advance(DT,0,1,0)
		abs_off.advance(DT,0,1,0)
	check(abs_on.front_slip_ratio > -.3 and abs_off.front_slip_ratio < -.7,"ABS independently prevents wheel lock")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("OVERSTEER PASSED: smooth tyre envelope, combined grip, independent assists, mirrored power slide and driver recovery.")
	quit(0 if failures.is_empty() else 1)
