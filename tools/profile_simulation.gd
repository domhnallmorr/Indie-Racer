extends SceneTree
## Fixed 60 Hz manual ticks isolate CPU work from rendering and catch-up ticks.
func _initialize() -> void:
	call_deferred("profile")

func profile() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_seed = 1234
	root.add_child(main)
	for body in main.find_children("*","CollisionObject3D",true,false):
		body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	main.process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frame
	var line: PackedVector3Array = main.ai_cars[0].get_node("Driver").race
	for i in range(main.ai_cars.size()):
		var car = main.ai_cars[i]
		var driver = car.get_node("Driver")
		var idx: int = i*line.size()/main.ai_cars.size()
		driver.index = idx
		driver.mode = driver.Mode.RACING
		car.global_position = car.track.to_global(line[idx])+Vector3.UP*.1
		var direction: Vector3 = line[(idx+1)%line.size()]-line[idx]
		car.rotation.y = atan2(-direction.x,-direction.z)
		car.sim.u = 65.0
		car.speed_mps = 65.0
		car.sim.gear = 5
		car.sim.front_omega = 65/car.parameters.values.front_radius_m
		car.sim.rear_omega = 65/car.parameters.values.rear_radius_m
		car.sim.engine_omega = car.sim.rear_omega*car.sim.ratio()
	var total := 0
	var planning := 0
	var integration := 0
	var zones := 0
	for tick in range(300):
		await physics_frame
		var start := Time.get_ticks_usec()
		for car in main.ai_cars:
			car.get_node("Driver")._update_index(car.track.to_local(car.global_position))
			car.get_node("Driver")._planned_speed()
		planning += Time.get_ticks_usec()-start
		start = Time.get_ticks_usec()
		for car in main.ai_cars:
			car.get_node("Driver")._physics_process(1.0/60.0)
		total += Time.get_ticks_usec()-start
		start = Time.get_ticks_usec()
		for car in main.ai_cars:
			car.update_zone_state()
		zones += Time.get_ticks_usec()-start
		if tick % 60 == 59:
			print("tick=",tick+1," all_drivers_ms=",total/float(tick+1)/1000," planner_ms=",planning/float(tick+1)/1000)
	# Separate model instances avoid changing the live cars during this benchmark.
	var sims: Array = []
	for car in main.ai_cars:
		var sim = load("res://game/vehicle/bicycle_model.gd").new()
		sim.configure(car.parameters.values)
		sims.append(sim)
	for tick in range(300):
		var start := Time.get_ticks_usec()
		for sim in sims:
			sim.advance(1.0/60.0,1,0,.1)
		integration += Time.get_ticks_usec()-start
	print("15 models integration_ms=",integration/300.0/1000)
	print("15 zone checks_ms=",zones/300.0/1000," pit_path_points=",main.track_data.pit_path.size())
	quit()
