extends SceneTree
const Model = preload("res://game/vehicle/bicycle_model.gd")
const Config = preload("res://game/vehicle/physics_config.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func validate() -> void:
	var config = Config.new()
	check(config.load_directory("res://content/vehicles/open_wheel/physics"),"Configuration loads")
	if not failures.is_empty():
		push_error(str(config.errors))
		quit(1)
		return
	var model = Model.new()
	# These checks exercise the underlying physics, including deliberate wheel lock.
	config.values.assistance_strength = 0.0
	model.configure(config.values)
	check(is_equal_approx(model.torque_at(10000,1),472),"Peak torque")
	check(is_equal_approx(model.torque_at(9500,1),467),"Curve interpolation")
	check(model.torque_at(10000,0) < 0,"Closed throttle engine braking")
	var seen_gears: Array = []
	for i in range(3600):
		model.advance(1.0/60,1,0,0)
		if not model.gear in seen_gears:
			seen_gears.append(model.gear)
		if i%600 == 599:
			print("ACCEL t=%d speed=%.1f gear=%d rpm=%.0f slip=%.2f clutch=%.2f" % [(i+1)/60,model.u*3.6,model.gear,model.rpm(),model.rear_slip_ratio,model.clutch])
	check(seen_gears.size() == 6,"Automatic acceleration uses all six gears: "+str(seen_gears))
	check(model.u > 65 and model.u < 105,"Plausible high speed")
	check(not model.select_gear(-1),"Reverse rejected while moving")
	check(not model.select_gear(1),"Over-rev downshift rejected")
	var peak_speed: float = model.u
	var lock_seen := false
	for i in range(600):
		model.advance(1.0/60,0,1,0)
		if model.front_slip_ratio < -.7:
			lock_seen = true
	check(absf(model.u) < .5,"Brakes stop car")
	check(lock_seen,"Hard braking can lock wheels")
	model.reset()
	model.select_gear(-1)
	for i in range(600):
		model.advance(1.0/60,1,0,0)
	check(model.u < -3 and absf(model.u)*3.6 <= 25.01,"Reverse drives backward and caps speed")
	model.reset()
	model.select_gear(0)
	for i in range(300):
		model.advance(1.0/60,1,0,0)
	check(absf(model.u) < .01,"Neutral does not drive wheels")
	check(model.rpm() <= config.values.redline_rpm+100,"Neutral fuel cut respects redline")
	model.reset()
	for i in range(1200):
		model.advance(1.0/60,1,0,0,0,0,9.81,true,1,80.0/3.6)
	check(model.u <= 80.0/3.6+.001 and model.u > 20,"Pit cap")
	for i in range(300):
		model.advance(1.0/60,1,0,0)
	check(model.u > 80.0/3.6+5,"Release restores acceleration")
	for sign_value in [-1,1]:
		model.reset()
		model.u = 40
		model.front_omega = 40/config.values.front_radius_m
		model.rear_omega = 40/config.values.rear_radius_m
		model.gear = 3
		model.engine_omega = model.rear_omega*model.ratio()
		for i in range(180):
			model.advance(1.0/60,.25,0,.12*sign_value)
			check(model.front_usage <= 1.001 and model.rear_usage <= 1.001,"Combined force stays in friction circle")
		check(model.yaw_rate*sign_value > .01,"Steering generates yaw in requested direction")
		check(is_finite(model.v) and absf(model.yaw_rate) < 5,"Cornering stable")
		print("TURN sign=%d u=%.2f v=%.2f yaw=%.2f slipF=%.2f slipR=%.2f" % [sign_value,model.u,model.v,model.yaw_rate,model.front_slip_angle,model.rear_slip_angle])
	model.reset()
	model.u = 50
	model.advance(.01,0,0,0,0,0,9.81,true)
	check(model.downforce_n > 5000 and model.drag_n > 1000,"Aero produces force")
	model.reset()
	model.advance(.1,0,0,0,0,1.53,9.69,true)
	check(model.v > 0,"Banking gravity acts in road plane")
	model.reset()
	model.advance(.1,1,0,1,0,0,9.81,false)
	check(model.front_load == 0 and model.rear_load == 0 and model.u == 0,"Airborne tyres cannot accelerate body")
	var slow = Model.new()
	var fast = Model.new()
	slow.configure(config.values)
	fast.configure(config.values)
	for i in range(1200):
		slow.advance(1.0/60,1,0,0)
		fast.advance(1.0/120,1,0,0)
		fast.advance(1.0/120,1,0,0)
	check(absf(slow.u-fast.u) < .5,"60/120 Hz integration agrees")
	DirAccess.make_dir_recursive_absolute("res://builds/invalid_physics")
	for section in config.NUMERIC:
		DirAccess.copy_absolute("res://content/vehicles/open_wheel/physics/"+section+".cfg","res://builds/invalid_physics/"+section+".cfg")
	var broken := ConfigFile.new()
	broken.load("res://builds/invalid_physics/chassis.cfg")
	broken.set_value("chassis","mass_kg",0)
	broken.save("res://builds/invalid_physics/chassis.cfg")
	var bad = Config.new()
	check(not bad.load_directory("res://builds/invalid_physics") and "mass_kg must be positive" in bad.errors,"Nonphysical configuration rejected")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("BICYCLE CHECK PASSED: torque, six gears, braking, reverse, neutral, limiter, slip forces, aero and banking. Top %.1f km/h" % (peak_speed*3.6))
	quit(0 if failures.is_empty() else 1)
