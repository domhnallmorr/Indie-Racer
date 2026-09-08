extends SceneTree
func _initialize() -> void:
	var config = load("res://game/vehicle/physics_config.gd").new()
	assert(config.load_directory("res://content/vehicles/open_wheel/physics"))
	var sim = load("res://game/vehicle/bicycle_model.gd").new()
	sim.configure(config.values)
	sim.gear = 0
	# Isolate lateral capability at 200 km/h on a steady 9-degree bank.
	for tick in range(600):
		sim.u = 200.0/3.6
		sim.front_omega = sim.u/config.values.front_radius_m
		sim.rear_omega = sim.u/config.values.rear_radius_m
		sim.advance(1.0/60,0,0,1,0,9.81*sin(deg_to_rad(9)),9.81*cos(deg_to_rad(9)))
	var radius: float = sim.u/sim.yaw_rate
	print("200 KPH CORNER: radius=", radius, " steer=", rad_to_deg(sim.steer), " front usage=", sim.front_usage, " rear usage=", sim.rear_usage)
	assert(radius < 115 and radius > 80, "Needs steering reserve for the 125 m reference corner")
	assert(absf(atan2(sim.v,sim.u)) < deg_to_rad(6), "Corner remains stable")
	quit()
