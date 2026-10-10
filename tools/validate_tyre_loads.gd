extends SceneTree
const Config = preload("res://game/vehicle/physics_config.gd")
const Model = preload("res://game/vehicle/bicycle_model.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok and message not in failures: failures.append(message)

func _initialize() -> void:
	var config = Config.new()
	if not config.load_directory("res://content/vehicles/open_wheel/physics"):
		push_error(str(config.errors))
		quit(1)
		return
	var sim = Model.new()
	sim.configure(config.values.duplicate(true))
	sim.front_load = 4000
	sim.rear_load = 6000
	for accel in [0.0,10.0,-10.0,1000.0,-1000.0]:
		sim.lateral_contact_acceleration = accel
		sim._update_wheel_loads()
		check(is_equal_approx(sim.wheel_loads[0]+sim.wheel_loads[1],4000),"Front axle load conserved")
		check(is_equal_approx(sim.wheel_loads[2]+sim.wheel_loads[3],6000),"Rear axle load conserved")
		for load_n in sim.wheel_loads: check(load_n >= 0,"Wheel lift never produces negative load")
		check(signf(sim.wheel_loads[1]-sim.wheel_loads[0]) == signf(accel),"Left turn loads right tyres, right turn loads left tyres")
		if absf(accel) == 10:
			var moment: float = sim.front_lateral_transfer_n*sim.p.front_track_m+sim.rear_lateral_transfer_n*sim.p.rear_track_m
			check(is_equal_approx(moment,sim.vehicle_mass_kg*accel*sim.p.cg_height_m),"Roll moment conserved before wheel lift")
	# Equal loads preserve the axle reference and catch accidental force doubling.
	sim.lateral_contact_acceleration = 0
	sim._update_wheel_loads()
	for slip in [0.0,.05,.4]:
		for angle in [.001,.08,.4]:
			var split: Vector2 = sim._wheel_force(0,slip,angle,90000,1)+sim._wheel_force(1,slip,angle,90000,1)
			check(split.is_equal_approx(sim._tyre(sim.front_load,slip,angle,90000,1)),"Equal-load split preserves axle force")
	# Reference values come from the independent executable/telemetry comparison.
	# Smooth gameplay arithmetic may differ slightly from ICR2 integer rounding.
	for row in [Vector3(2688,4334,0),Vector3(7637,9374,1),Vector3(4226,6500,2),Vector3(9330,10676,3)]:
		var peak: float = .5*sim._peak_force(2*row.x,1,int(row.z))
		check(absf(peak-row.y) < 8,"Indy capacity matches the plotted proposal for wheel "+str(row.z))
	check(sim._peak_force(15000,1,0) < sim._peak_force(15000,1,2),"Front pair uses stronger load sensitivity")
	for index in range(4):
		for load_n in [.00001,100.0,12000.0,50000.0]:
			var peak: float = .5*sim._peak_force(2*load_n,1,index)
			check(is_finite(peak) and peak >= 0,"Load curve remains finite through wheel lift and extreme loads")
	var ref_load: float = sim.p.reference_load_n
	check(sim._peak_force(2*ref_load,1) < 2*sim._peak_force(ref_load,1),"Double load gives less than double peak grip")
	check(sim._peak_force(.5*ref_load,1)+sim._peak_force(1.5*ref_load,1) < 2*sim._peak_force(ref_load,1),"Unequal loading reduces combined peak grip")
	check(sim._peak_force(0,1) == 0 and sim._peak_force(ref_load,0) == 0,"Unloaded or gripless tyres have no capacity")
	for accel in [0.0,10.0,1000.0]:
		sim.lateral_contact_acceleration = accel
		sim._update_wheel_loads()
		for i in range(4):
			var force: Vector2 = sim._wheel_force(i,.5,.4,90000,1)
			check(force.is_finite() and force.length() <= sim.wheel_peaks[i]+.001,"Combined wheel force is finite and respects load-sensitive peak")
			if sim.wheel_loads[i] > 0:
				check(sim.wheel_demand[i] > 1 and sim.wheel_usage[i] < 1,"Sliding stays identifiable after force falls below peak")
	# Roll balance redistributes the moment; it cannot alter total axle loads.
	sim.front_load = 5000
	sim.rear_load = 5000
	sim.lateral_contact_acceleration = 15
	var capacities: Array[Vector2] = []
	for front_fraction in [.35,.65]:
		sim.p.front_roll_stiffness_fraction = front_fraction
		sim._update_wheel_loads()
		for i in range(4): sim._wheel_force(i,0,.05,90000,1)
		capacities.append(Vector2(sim.wheel_peaks[0]+sim.wheel_peaks[1],sim.wheel_peaks[2]+sim.wheel_peaks[3]))
	check(capacities[1].x < capacities[0].x and capacities[1].y > capacities[0].y,"More front roll stiffness trades front grip for rear grip")
	# Bank gravity alone must not be treated as tyre-generated roll moment.
	sim.configure(config.values.duplicate(true))
	sim.gear = 0
	for i in range(60): sim.advance(1.0/60,0,0,0,0,4.0,8.9,true,0.0)
	check(absf(sim.lateral_contact_acceleration) < .2,"Bank gravity without tyre force does not create large roll transfer")
	sim.advance(.02,0,0,0,0,0,0,false)
	check(sim.lateral_contact_acceleration == 0,"Airborne clears lateral transfer history")
	for load_n in sim.wheel_loads: check(load_n == 0,"Airborne wheel loads vanish")
	sim.reset()
	for load_n in sim.wheel_loads: check(load_n == 0,"Reset clears wheel diagnostics")
	# Roll balance should produce a measurable change in a sustained corner,
	# not just different diagnostic numbers. Test both steering directions.
	for direction in [-1.0,1.0]:
		var yaw: Array[float] = []
		for balance in [.35,.65]:
			sim.configure(config.values.duplicate(true))
			sim.p.front_roll_stiffness_fraction = balance
			sim.gear = 0
			for i in range(600):
				sim.u = 45
				sim.front_omega = sim.u/sim.p.front_radius_m
				sim.rear_omega = sim.u/sim.p.rear_radius_m
				sim.advance(1.0/60,0,0,4.0*direction/sim.steering_lock_at_speed(Vector2(sim.u,sim.v).length()))
			yaw.append(sim.yaw_rate*direction)
		print("ROLL BALANCE direction=",direction," yaw at 35/65% front=",yaw)
		check(yaw[0] > yaw[1]+.001 and yaw[1] > 0,"Forward roll balance reduces steady corner rotation")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("TYRE LOADS PASSED: conservation, direction, wheel lift, load sensitivity, force limits, roll balance, bank/airborne/reset.")
	quit(0 if failures.is_empty() else 1)
