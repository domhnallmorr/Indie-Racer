extends SceneTree
const Config = preload("res://game/vehicle/physics_config.gd")
const Model = preload("res://game/vehicle/bicycle_model.gd")
const Aero = preload("res://game/vehicle/aero_model.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _initialize() -> void:
	var config = Config.new()
	if not config.load_directory("res://content/vehicles/open_wheel/physics"):
		push_error(str(config.errors))
		quit(1)
		return
	var sim = Model.new()
	sim.configure(config.values.duplicate(true))
	check(is_equal_approx(sim.steering_lock_at_speed(0),28),"Full pit manoeuvring travel")
	check(is_equal_approx(sim.steering_lock_at_speed(37.5),16.25),"Explicit speed-only interpolation")
	for speed in [75.0,90.0,105.0,-90.0]:
		check(is_equal_approx(sim.steering_lock_at_speed(speed),4.5),"Constant high-speed range, including reverse")
	sim.p.steering_assistance = .5
	check(is_equal_approx(sim.steering_lock_at_speed(100),16.25),"Partial help interpolates range")
	for master in [0.0,1.0]:
		sim.p.assistance_strength = master
		sim.p.steering_assistance = 1.0-master
		for speed in [0.0,30.0,100.0]:
			check(is_equal_approx(sim.steering_lock_at_speed(speed),28),"Either help-off or master-off gives fixed physical lock")
	# Test the integration path, not just the helper: the same input/initial angle
	# must produce the same steering travel and rate under different car states.
	var reference := NAN
	for wing in [3.0,6.0,9.0,18.0]:
		for grip in [0.0,.48,1.0]:
			for direction in [-1.0,1.0]:
				for yaw in [-1.0,0.0,1.0]:
					sim.configure(config.values.duplicate(true))
					Aero.apply(sim.p,"speedway",wing,3.0)
					sim.u = 100
					sim.v = 10*direction
					sim.yaw_rate = yaw
					sim.turn_normal_factors = Vector2(.5,0)
					sim.dirty_air_strength = .8
					sim.wind_body_mps = Vector2(20,10)
					sim._integrate(.001,1,0,.4*direction,0,5,8.5,grip>0,grip,INF)
					if is_nan(reference): reference = absf(sim.steer)
					check(is_equal_approx(absf(sim.steer),reference),"Wings, grip, yaw, slide direction and contact do not alter steering rate")
					check(is_equal_approx(sim.assisted_steering_lock_deg,4.5),"No hidden gain from wings, bank, yaw, surface or wake")
	# A physical wheel must cross centre within the same tick even when the old
	# digital slew limit would leave the front wheels steering the wrong way.
	for hz in [60,120]:
		for direct in [false,true]:
			sim.configure(config.values.duplicate(true))
			sim.direct_steering = direct
			sim.u = 20
			sim.steer = deg_to_rad(12)
			sim.advance(1.0/hz,0,0,-.5,0,0,9.81,false)
			if direct:
				check(is_equal_approx(sim.steer,-.5*deg_to_rad(sim.assisted_steering_lock_deg)),"Physical wheel reaches commanded countersteer in one tick")
			else:
				check(sim.steer > deg_to_rad(11),"Keyboard retains its steering slew limit")
	# Holding the wheel through a lift must not add angle at speed. Include both
	# sides and both physics tick rates; tyre/load changes still evolve normally.
	for hz in [60,120]:
		for direction in [-1.0,1.0]:
			sim.configure(config.values.duplicate(true))
			sim.u = 100
			sim.gear = 6
			sim.automatic = false
			sim.front_omega = sim.u/sim.p.front_radius_m
			sim.rear_omega = sim.u/sim.p.rear_radius_m
			sim.engine_omega = sim.rear_omega*sim.ratio()
			sim.steer = deg_to_rad(1.2)*direction
			for i in range(hz):
				sim.advance(1.0/hz,0,0,1.2/4.5*direction)
				check(is_equal_approx(rad_to_deg(sim.steer),1.2*direction),"Lift does not add steering at constant driver input")
			check(sim.u > 75,"Lift test remains in high-speed steering range")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("STEERING PASSED: predictable speed-only/direct mapping, environmental independence, mirrored lift at 60/120 Hz.")
	quit(0 if failures.is_empty() else 1)
