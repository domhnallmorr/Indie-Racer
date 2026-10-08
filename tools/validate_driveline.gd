extends SceneTree
const Model = preload("res://game/vehicle/bicycle_model.gd")
const Config = preload("res://game/vehicle/physics_config.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func sample(p: Dictionary, gear: int, gas: float, hz: int) -> Dictionary:
	var sim = Model.new()
	sim.configure(p.duplicate(true))
	sim.set_vehicle_mass(800)
	sim.automatic = false
	sim.gear = gear
	sim.u = -5.0 if gear < 0 else 70.0/3.6
	sim.front_omega = sim.u/p.front_radius_m
	sim.rear_omega = sim.u/p.rear_radius_m
	sim.engine_omega = sim.rear_omega*sim.ratio()
	sim.clutch = 1
	sim.throttle = gas
	var low := INF
	var high := -INF
	for i in range(hz):
		sim.advance(1.0/hz,gas,0,0)
		if i >= int(hz*.8):
			low = minf(low,sim.clutch_torque_min_nm)
			high = maxf(high,sim.clutch_torque_max_nm)
	return {"u":sim.u,"rpm":sim.rpm(),"slip":sim.rear_slip_ratio,"low":low,"high":high}

func _initialize() -> void:
	var config = Config.new()
	assert(config.load_directory("res://content/vehicles/open_wheel/physics"))
	for scenario in ["first_coast","first_cruise","first_power","second_cruise","short_gearing","stiff_clutch","reverse"]:
		var p: Dictionary = config.values.duplicate(true)
		var gear := -1 if scenario == "reverse" else (2 if scenario == "second_cruise" else 1)
		var gas := 0.0 if scenario == "first_coast" else (.5 if scenario == "first_power" else .2)
		if scenario == "short_gearing": p.final_drive = 5.0
		if scenario == "stiff_clutch": p.clutch_stiffness_nm_s *= 2.0; p.inertia_kgm2 *= .5
		var reference := sample(p,gear,gas,4000)
		for hz in [60,120,240]:
			var result := sample(p,gear,gas,hz)
			check(absf(result.u-reference.u) < .03,scenario+": road speed converges at "+str(hz)+" Hz")
			check(absf(result.rpm-reference.rpm) < 10,scenario+": engine speed converges at "+str(hz)+" Hz")
			check(absf(result.slip-reference.slip) < .002,scenario+": tyre slip converges at "+str(hz)+" Hz")
			check(result.high-result.low < 40,scenario+": steady input does not cause alternating clutch saturation")
			if scenario == "first_cruise":
				check(result.low > 0 and result.high < 50,"Cruise transmits small positive torque throughout the tick")
			if scenario == "first_coast":
				check(result.high < 0 and result.slip < 0,"Coasting retains smooth engine braking")
		print("DRIVELINE ",scenario," reference=",reference)
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("DRIVELINE PASSED: stable clutch torque and 60/120/240 Hz convergence against 4000 Hz; coast, cruise, power, reverse, custom gearing and clutch stiffness.")
	quit(0 if failures.is_empty() else 1)
