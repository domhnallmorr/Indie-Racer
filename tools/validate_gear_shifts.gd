extends SceneTree
const Model = preload("res://game/vehicle/bicycle_model.gd")
const Config = preload("res://game/vehicle/physics_config.gd")
var failures: Array[String] = []

func _initialize() -> void:
	var config = Config.new()
	if not config.load_directory("res://content/vehicles/open_wheel/physics"):
		push_error(str(config.errors))
		quit(1)
		return
	for assistance in [1.0, 0.0]:
		for hz in [60, 120]:
			config.values.assistance_strength = assistance
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
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("GEAR SHIFTS PASSED: sequential acceleration at 60/120 Hz, with and without assists.")
	quit(0 if failures.is_empty() else 1)
