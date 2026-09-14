extends SceneTree

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	var car = main.ai_cars[0]
	var driver = car.get_node("Driver")
	driver.mode = driver.Mode.RACING
	for start in [0,10,driver.race.size()-1]:
		driver.index = start
		for blend in [Vector2.ZERO,Vector2(-1,-1),Vector2(1,1),Vector2(-.4,1),Vector2(.7,-1)]:
			driver.racecraft.lane = blend.x
			driver.racecraft.target_lane = blend.y
			var samples: PackedVector3Array = driver.racecraft.planner_samples(driver,340)
			for i in range(samples.size()):
				assert(samples[i].distance_to(driver.racecraft.ahead(driver,float(i*5-25))) < .0001,"Ordered planner samples must match independent path lookups, including transitions and lap wrapping")
	driver.racecraft.lane = 0
	driver.racecraft.target_lane = 0
	for start in [0,10,driver.race.size()-1]:
		driver.index = start
		for distance in [-20.0,-1.0,0.0,10.0,100.0,500.0,driver.race_length_m+10.0]:
			assert(driver._ahead(distance).distance_to(walk_line(driver.race,start,distance,driver.race_length_m)) < .003, "Cached lookup must match linear distance traversal")
	var p: Dictionary = car.parameters.values
	var original: Dictionary = p.duplicate(true)
	var a := Vector3.ZERO
	var b := Vector3(10,0,0)
	var c := Vector3(20,0,1)
	driver.surface_normals[b] = Vector3.UP
	var baseline: float = driver._corner_speed(a,b,c)
	assert(is_finite(baseline) and baseline > 0)
	driver.racecraft.target_lane = 1
	assert(driver._corner_speed(a,b,c) < baseline,"A committed lane change reserves cornering capacity before moving")
	driver.racecraft.target_lane = 0
	p.friction_coefficient *= .7
	assert(driver._corner_speed(a,b,c) < baseline, "Lower grip must lower apex speed")
	p.assign(original)
	p.downforce_area_m2 = 0.0
	assert(driver._corner_speed(a,b,c) < baseline, "Less downforce must lower apex speed")
	p.assign(original)
	assert(is_inf(driver._corner_speed(a,b,Vector3(20,0,0))), "Straight must have no speed cap")
	# Banking slopes down towards this right-hand bend (+Z).
	driver.surface_normals[b] = Vector3(0,cos(.15),sin(.15))
	assert(driver._corner_speed(a,b,c) > baseline, "Helpful banking must increase corner capacity")
	driver.surface_normals.clear()
	# A distant bend must be visible even with more than 80 intervening points.
	driver.mode = driver.Mode.RACING
	driver.race.clear()
	for i in range(701):
		driver.race.append(Vector3(i,0,0))
	driver.index = 0
	assert(driver._ahead(500).is_equal_approx(Vector3(500,0,0)))
	assert(driver._ahead(-10).is_equal_approx(Vector3(10,0,0)), "Backward sample must wrap over lap seam")
	driver.index = 20
	car.global_position = car.track.to_global(Vector3(20,0,0))
	assert(driver._ahead(-10).is_equal_approx(Vector3(10,0,0)), "Curvature needs a sample behind the car")
	driver.race_length_m = 1400
	car.speed_mps = 30
	assert(is_inf(driver._planned_speed()), "Clear straight must allow full acceleration")
	car.speed_mps = 120
	assert(is_finite(driver._planned_speed()), "High speed must extend horizon to distant turn")
	print("AI PLANNER PASSED: grip, aero, banking, uncapped straights and extended braking lookahead.")
	quit()

func walk_line(points: PackedVector3Array, start: int, distance: float, total: float) -> Vector3:
	var remaining := fposmod(distance,total)
	var current := start
	for unused in range(points.size()+1):
		var next := (current+1)%points.size()
		var length := points[current].distance_to(points[next])
		if remaining <= length:
			return points[current].lerp(points[next],remaining/maxf(length,.001))
		remaining -= length
		current = next
	return points[current]
