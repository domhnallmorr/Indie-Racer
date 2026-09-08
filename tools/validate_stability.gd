extends SceneTree
const Config = preload("res://game/vehicle/physics_config.gd")
const Model = preload("res://game/vehicle/bicycle_model.gd")

func _initialize() -> void:
	var config = Config.new()
	if not config.load_directory("res://content/vehicles/open_wheel/physics"):
		quit(1)
		return
	var failed := false
	for speed in [20.0,40.0,60.0]:
		var sim = Model.new()
		sim.configure(config.values)
		sim.u = speed
		sim.gear = 4 if speed < 50 else 6
		sim.front_omega = speed/config.values.front_radius_m
		sim.rear_omega = speed/config.values.rear_radius_m
		sim.engine_omega = maxf(2500*TAU/60,sim.rear_omega*sim.ratio())
		var max_slip := 0.0
		var peak_yaw := 0.0
		for i in range(600):
			var input := 1.0 if i < 180 else (-1.0 if i < 360 else 0.0)
			# Abrupt full-key steering, full throttle, then braking and release.
			sim.advance(1.0/60,1.0 if i < 240 else 0.0,.6 if i >= 240 and i < 360 else 0.0,input)
			if absf(sim.u) > 5:
				max_slip = maxf(max_slip,absf(rad_to_deg(atan2(sim.v,absf(sim.u)))))
			peak_yaw = maxf(peak_yaw,absf(sim.yaw_rate))
		if max_slip > 6 or absf(sim.yaw_rate) > .05 or not is_finite(sim.u):
			failed = true
			push_error("Unstable keyboard manoeuvre at "+str(speed))
		print("STABILITY start=%.0f km/h max sideslip=%.2f deg final yaw=%.3f peak yaw=%.3f" % [speed*3.6,max_slip,sim.yaw_rate,peak_yaw])
	if not failed:
		print("STABILITY PASSED: abrupt left/right keyboard input, throttle, braking and release.")
	quit(1 if failed else 0)
