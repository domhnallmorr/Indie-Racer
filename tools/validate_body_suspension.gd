extends SceneTree
const Body = preload("res://game/vehicle/body_suspension.gd")
const Config = preload("res://game/vehicle/physics_config.gd")
const Model = preload("res://game/vehicle/bicycle_model.gd")
const PROFILE = "res://content/vehicles/open_wheel/physics/indy_suspension.cfg"
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _initialize() -> void:
	var body = Body.new()
	check(body.configure_indy(PROFILE),"Profile loads")
	check(body.source_shocks == [85.0,70.0,75.0,65.0],"Confirmed ICR2 corner values")
	# Reducing compliance must not change the tested transfer response. The
	# previous profile had one quarter the roll K/I; C then scales likewise.
	var previous = Body.new()
	previous.configure_indy(PROFILE)
	previous.roll_stiffness_nm_rad *= .25
	previous.roll_inertia_kgm2 *= .25
	for i in range(4000):
		var moment: float = 9000.0 if i < 1500 else (-4500.0 if i < 2500 else 0.0)
		body.advance(.0005,moment,-3000,1.15,true)
		previous.advance(.0005,moment,-3000,1.15,true)
		check(absf(body.roll*4-previous.roll) < .000001,"Quarter lean under turn-in, reversal and release")
		check(absf(body.roll_reaction_nm-previous.roll_reaction_nm) < .001,"Compliance change preserves roll transfer dynamics")
		check(absf(body.pitch-previous.pitch) < .000001,"Pitch response unchanged")
	body.reset()
	for i in range(16000): body.advance(.0005,4000,-3000,1,true)
	check(absf(body.roll_reaction_nm-4000) < .01,"Steady roll reaction matches applied moment")
	check(absf(body.pitch_reaction_nm+3000) < .01,"Braking reaction matches applied moment")
	check(body.roll > 0 and body.pitch < 0,"Roll/pitch signs")
	check(absf(body.roll-4000/body.roll_stiffness_nm_rad) < .00001,"Roll equilibrium compliance")
	var energy: float = .5*body.roll_stiffness_nm_rad*body.roll*body.roll+.5*body.roll_inertia_kgm2*body.roll_rate*body.roll_rate
	for i in range(1000):
		body.advance(.0005,0,0,1,true)
		var next: float = .5*body.roll_stiffness_nm_rad*body.roll*body.roll+.5*body.roll_inertia_kgm2*body.roll_rate*body.roll_rate
		check(next <= energy+.00001,"Unforced damped mode dissipates energy")
		energy = next
	body.advance(.0005,4000,3000,1,false)
	check(body.roll == 0 and body.pitch == 0 and body.roll_reaction_nm == 0,"Airborne clears constrained body modes")
	var config = Config.new()
	check(config.load_directory("res://content/vehicles/open_wheel/physics"),"Physics config loads")
	var outcomes: Array[Vector3] = []
	for hz in [60,120]:
		var sim = Model.new()
		sim.configure(config.values.duplicate(true))
		sim.suspension.configure_indy(PROFILE)
		sim.p.stability_assistance = 0
		sim.u = 60
		sim.front_omega = 60/sim.p.front_radius_m
		sim.rear_omega = 60/sim.p.rear_radius_m
		sim.gear = 0
		for i in range(2*hz):
			sim.advance(1.0/hz,0,.1 if i > hz else 0,.05)
			check(is_finite(sim.suspension.roll) and is_finite(sim.suspension.pitch),"Finite integrated body modes")
			check(absf(sim.wheel_loads[0]+sim.wheel_loads[1]-sim.front_load) < .001,"Front axle conservation")
			check(absf(sim.wheel_loads[2]+sim.wheel_loads[3]-sim.rear_load) < .001,"Rear axle conservation")
			for load_n in sim.wheel_loads: check(load_n >= 0,"Nonnegative wheel loads")
		outcomes.append(Vector3(sim.u,sim.suspension.roll,sim.suspension.pitch))
		print("BODY hz=",hz," outcome=",outcomes[-1])
		sim.advance(.02,0,0,0,0,0,0,false)
		for load_n in sim.wheel_loads: check(load_n == 0,"Airborne model loads zero")
	check(outcomes[0].distance_to(outcomes[1]) < .04,"60/120 Hz convergence")
	for failure in failures.slice(0,12): push_error(failure)
	if failures.is_empty(): print("BODY SUSPENSION PASSED: setup, equilibrium, damping, signs, loads, airborne and cadence.")
	quit(0 if failures.is_empty() else 1)
