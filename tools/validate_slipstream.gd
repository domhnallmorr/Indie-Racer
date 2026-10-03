extends SceneTree
const Tow = preload("res://game/vehicle/slipstream.gd")
const Model = preload("res://game/vehicle/bicycle_model.gd")
const Config = preload("res://game/vehicle/physics_config.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func wake(gap: float, lateral := 0.0, angle := 0.0, height := 0.0, speed := 70.0, leader_speed := 70.0) -> float:
	return Tow.strength(Transform3D(Basis(Vector3.UP,angle),Vector3(lateral,height,gap)),speed,Transform3D.IDENTITY,leader_speed)

func running_model(config):
	var model = Model.new()
	model.configure(config.values.duplicate(true))
	model.u = 70.0
	model.gear = 5
	model.front_omega = model.u/model.p.front_radius_m
	model.rear_omega = model.u/model.p.rear_radius_m
	model.engine_omega = model.rear_omega*model.ratio()
	return model

func dirty_wake(gap: float, lateral := 0.0, angle := 0.0, height := 0.0, speed := 70.0) -> float:
	return Tow.strength(Transform3D(Basis(Vector3.UP,angle),Vector3(lateral,height,gap)),speed,Transform3D.IDENTITY,70.0,true)

func validate_dirty_air(config) -> void:
	check(dirty_wake(4.4) == 1.0 and dirty_wake(6.0) == 1.0,"Dirty air stays strong at the gearbox")
	check(dirty_wake(25) > dirty_wake(50) and dirty_wake(50) > dirty_wake(74),"Dirty air fades with distance")
	check(dirty_wake(20,1) > 0 and dirty_wake(20,1) < dirty_wake(20),"Dirty air fades laterally")
	check(dirty_wake(0) == 0 and dirty_wake(-10) == 0 and dirty_wake(75) == 0,"Dirty air only behind and within range")
	check(dirty_wake(20,4) == 0 and dirty_wake(20,0,PI) == 0 and dirty_wake(20,0,0,4) == 0 and dirty_wake(20,0,0,0,15) == 0,"Dirty air excludes adjacent, oncoming, separated and slow cars")
	var clean = running_model(config)
	var dirty = running_model(config)
	dirty.dirty_air_target = 1.0
	dirty.dirty_air_strength = 1.0
	dirty.slipstream_target = 1.0
	dirty.slipstream_strength = 1.0
	clean.advance(.001,1,0,0)
	dirty.advance(.001,1,0,0)
	check(is_equal_approx(dirty.front_downforce_n/clean.front_downforce_n,.8),"Dirty air loses 20 percent front downforce")
	check(is_equal_approx(dirty.rear_downforce_n/clean.rear_downforce_n,.9),"Dirty air loses 10 percent rear downforce")
	check(dirty.front_load < clean.front_load and dirty.rear_load < clean.rear_load,"Dirty air reduces actual tyre loads")
	check(dirty.front_downforce_n/dirty.downforce_n < clean.front_downforce_n/clean.downforce_n,"Aero balance shifts rearward")
	check(is_equal_approx(dirty.drag_n/clean.drag_n,.91),"Dirty air retains tow drag benefit")
	dirty.dirty_air_target = 0.0
	dirty.advance(1.0/60,1,0,0)
	check(dirty.dirty_air_strength > .8 and dirty.dirty_air_strength < 1.0,"Dirty air releases smoothly")
	for tick in range(120):
		dirty.advance(1.0/60,1,0,0)
	check(dirty.dirty_air_strength < .001,"Clean air recovers after release")
	dirty.dirty_air_target = 1.0
	dirty.reset()
	check(dirty.dirty_air_target == 0 and dirty.dirty_air_strength == 0,"Reset clears dirty air")
	dirty.dirty_air_target = 1.0
	dirty.advance(1.0/60,0,0,0)
	check(dirty.dirty_air_strength > 0 and dirty.dirty_air_strength < .1,"Dirty air builds smoothly")
	dirty.advance(.001,0,0,0,0,0,9.81,false)
	check(dirty.downforce_n == 0 and dirty.front_downforce_n == 0 and dirty.rear_downforce_n == 0,"Airborne axle loads remain zero")

func validate() -> void:
	check(is_equal_approx(wake(8),1.0),"Close aligned wake reaches full strength")
	check(wake(25) > wake(50) and wake(50) > wake(74),"Wake fades with distance")
	for gap in [-20.0,0.0,4.0,75.0,100.0]:
		check(wake(gap) == 0.0,"No wake ahead, overlapping or beyond range: "+str(gap))
	check(wake(20,1) > 0 and wake(20,1) < wake(20),"Lateral fade")
	check(wake(20,4) == 0 and wake(20,0,PI) == 0 and wake(20,0,0,4) == 0,"Adjacent, oncoming and separate levels excluded")
	check(wake(20,0,0,0,15) == 0 and wake(20,0,0,0,70,0) == 0,"Slow follower and stopped leader excluded")
	var config = Config.new()
	check(config.load_directory("res://content/vehicles/open_wheel/physics"),"Physics loads")
	validate_dirty_air(config)
	var clean = running_model(config)
	var towed = running_model(config)
	towed.slipstream_target = 1.0
	towed.slipstream_strength = 1.0
	clean.advance(.001,1,0,0)
	towed.advance(.001,1,0,0)
	check(is_equal_approx(towed.drag_n/clean.drag_n,0.91),"Tow reduces drag by 9 percent at matching airspeed")
	check(is_equal_approx(towed.downforce_n,clean.downforce_n) and is_equal_approx(towed.front_downforce_n,clean.front_downforce_n) and is_equal_approx(towed.rear_downforce_n,clean.rear_downforce_n),"Tow preserves total and axle downforce at matching airspeed")
	for tick in range(1800):
		clean.advance(1.0/60,1,0,0)
		towed.advance(1.0/60,1,0,0)
	print("TOW SPEED clean=%.2f km/h tow=%.2f km/h gain=%.2f km/h" % [clean.u*3.6,towed.u*3.6,(towed.u-clean.u)*3.6])
	check(towed.u > clean.u+.1,"Reduced drag produces extra speed at full throttle within existing gearing")
	var before: float = towed.u
	towed.slipstream_target = 0.0
	towed.advance(1.0/60,1,0,0)
	check(towed.slipstream_strength > .8 and absf(towed.u-before) < .2,"Pulling out fades tow without deleting gained speed")
	for tick in range(120):
		towed.advance(1.0/60,1,0,0)
	check(towed.slipstream_drag_reduction < .0001,"Drag returns to clean air after release")
	towed.reset()
	check(towed.slipstream_target == 0 and towed.slipstream_strength == 0 and towed.slipstream_drag_reduction == 0,"Reset clears tow")
	towed.slipstream_target = 1.0
	towed.advance(1.0/60,0,0,0)
	check(towed.slipstream_strength > 0 and towed.slipstream_strength < .1,"Tow builds progressively")
	# Real scene registration and eligibility; same query serves player and AI.
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_file = "res://content/rosters/icr2_test/manifest.json"
	main.roster_seed = 1234
	root.add_child(main)
	main.player.driving_enabled = false
	for car in main.ai_cars:
		car.get_node("Driver").set_physics_process(false)
	await physics_frame
	var player = main.player
	var leader = main.ai_cars[0]
	var follower = main.ai_cars[1]
	for car in [player,leader,follower]:
		car.global_transform = Transform3D.IDENTITY
		if car == player:
			car.sim.u = 70.0
		car.speed_mps = 70.0
		car.set_meta("pit_ghost",false)
		car.player_state.is_in_pit_lane = false
		car.player_state.is_in_pit_speed_zone = false
	leader.global_position = Vector3(0,0,-10)
	follower.global_position = Vector3(0,0,10)
	check(Tow.sample(player) > .99,"Player receives AI tow")
	check(Tow.sample(follower) > .99,"AI receives player tow")
	check(Tow.sample(leader) == 0,"Leader receives no benefit from cars behind")
	var pack_strength := Tow.sample(follower)
	var dirty_pack_strength := Tow.sample(follower,true)
	leader.slipstream_enabled = false
	check(is_equal_approx(Tow.sample(follower,true),dirty_pack_strength),"Extra pack cars cannot stack dirty air")
	check(is_equal_approx(Tow.sample(follower),pack_strength),"Extra pack cars cannot stack tow")
	player.slipstream_enabled = false
	check(Tow.sample(follower) == 0,"Disabled sources produce no wake")
	leader.slipstream_enabled = true
	check(Tow.sample(follower) > 0,"AI receives AI tow")
	for flag in ["retired","pit_ghost"]:
		leader.set_meta(flag,true)
		check(Tow.sample(follower) == 0,"Excluded source: "+flag)
		leader.set_meta(flag,false)
	leader.player_state.is_in_pit_lane = true
	check(Tow.sample(follower) == 0,"Pit source excluded")
	leader.player_state.is_in_pit_lane = false
	follower.player_state.is_in_pit_speed_zone = true
	check(Tow.sample(follower) == 0,"Pit follower excluded")
	follower.player_state.is_in_pit_speed_zone = false
	# Exercise the actual shared drive_step wiring on the racing straight.
	player.slipstream_enabled = true
	for car in [player,leader,follower]:
		car.player_state.request_departure()
		car.global_transform = car.track.global_transform*Transform3D(Basis(Vector3.UP,-PI/2),Vector3(0,.05,125))
	leader.global_position += -leader.global_basis.z*10.0
	follower.global_position += follower.global_basis.z*10.0
	player.drive_step(1.0/60,1,0,0)
	follower.update_slipstream(1.0/60)
	check(player.sim.slipstream_target > .9 and player.sim.slipstream_drag_reduction > 0,"Player drive step applies tow")
	check(player.sim.dirty_air_target > .9 and player.sim.dirty_air_strength > 0,"Player drive step applies dirty air")
	player.dirty_air_enabled = false
	player.drive_step(1.0/60,1,0,0)
	check(player.sim.dirty_air_target == 0 and player.sim.slipstream_target > .9,"Dirty air can be disabled independently of tow")
	check(follower.slipstream_target > .9 and follower.slipstream_drag_reduction > 0,"Reference AI applies tow")
	var driver = follower.get_node("Driver")
	driver.mode = driver.Mode.RACING
	driver._update_index(follower.track.to_local(follower.global_position))
	follower.slipstream_speed_fraction = 0.0
	var clean_target: float = driver._planned_speed()
	follower.slipstream_speed_fraction = .05
	check(driver._planned_speed() > clean_target,"Reference AI exploits tow on clear straight")
	driver.car_ghost = false
	driver.racecraft.update(driver,1.0/60)
	check(driver._traffic_speed(100.0) < 100.0,"Traffic still limits boosted AI target")
	var corner_index := -1
	for at in range(driver.race.size()):
		if driver._tow_straight_weight(at) == 0.0:
			corner_index = at
			break
	check(corner_index >= 0,"Fixture has a corner")
	if corner_index >= 0:
		driver.index = corner_index
		follower.global_position = follower.track.to_global(driver.race[corner_index])
		follower.slipstream_speed_fraction = 0.0
		var corner_target: float = driver._planned_speed()
		follower.slipstream_speed_fraction = .06
		check(driver._planned_speed() <= corner_target+.0001,"Reference tow does not increase corner target")
	follower.reset_dynamics()
	check(follower.slipstream_speed_fraction == 0 and follower.slipstream_strength == 0,"Reference reset clears tow and coast allowance")
	main.free()
	# Bicycle AI uses the exact player drive path as well.
	main = load("res://game/main/main.tscn").instantiate()
	main.roster_file = "res://content/rosters/default/manifest.json"
	root.add_child(main)
	main.player.driving_enabled = false
	for car in main.ai_cars:
		car.get_node("Driver").set_physics_process(false)
	await physics_frame
	leader = main.ai_cars[0]
	follower = main.ai_cars[1]
	for car in [leader,follower]:
		car.player_state.request_departure()
		car.set_meta("pit_ghost",false)
		car.sim.u = 70.0
		car.global_transform = car.track.global_transform*Transform3D(Basis(Vector3.UP,-PI/2),Vector3(0,.05,125))
	leader.global_position += -leader.global_basis.z*10.0
	leader.update_zone_state()
	follower.drive_step(1.0/60,1,0,0)
	check(follower.sim.slipstream_target > .9 and follower.sim.slipstream_drag_reduction > 0,"Bicycle AI drive step applies tow")
	check(follower.sim.dirty_air_target == 0,"Dirty air is player-only")
	main.free()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("SLIPSTREAM PASSED: geometry, speed gain, dirty-air axle loads, smooth transitions, player/AI, pack cap and exclusions.")
	quit(0 if failures.is_empty() else 1)
