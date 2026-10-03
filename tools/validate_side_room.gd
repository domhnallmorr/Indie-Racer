extends SceneTree
## Independent original neighbour scan, including squeezed and launch paths.
func _initialize() -> void:
	call_deferred("validate")

func original(driver, distance: float) -> Vector3:
	var craft = driver.racecraft
	var point: Vector3 = craft.path_point(driver,distance,craft.lane)
	if craft.launch_weight > 0:
		point = point.lerp(craft.track_lane_point(driver,distance,craft.launch_lateral_m),craft.launch_weight)
	var minimum := -8.0
	var maximum := 8.0
	var alongside := false
	for other in craft.nearby:
		if absf(other.gap) >= 18: continue
		var side: float = craft.own.y-other.lateral
		if absf(side) < .001: continue
		alongside = true
		var weight := (1.0-smoothstep(9.0,18.0,absf(other.gap)))*smoothstep(0.0,1.0,absf(side))
		if other.gap < 0:
			var clearance: float = craft._rear_bumper_clearance(driver,other.car,other.gap,craft.target_lane)
			weight *= 1.0-smoothstep(0.0,craft.rear_merge_bumper_margin_m,clearance)
		if side > 0:
			minimum = maxf(minimum,lerpf(-8.0,other.lateral+3.2,weight))
		else:
			maximum = minf(maximum,lerpf(8.0,other.lateral-3.2,weight))
	if not alongside: return point
	var at := fposmod(driver.race_distances[driver.index]+distance,driver.race_length_m)
	var low: Vector3 = driver._sample_path(craft.inner,driver.race_distances,at)
	var high: Vector3 = driver._sample_path(craft.outer,driver.race_distances,at)
	var across := high-low
	var lateral := (point-low).dot(across)/maxf(across.length_squared(),.001)*16.0-8.0
	lateral = clampf(lateral,minimum,maximum) if minimum <= maximum else craft.own.y
	return low.lerp(high,clampf((lateral+8.0)/16.0,0,1))

func validate() -> void:
	var max_error := 0.0
	var cases := 0
	for track_id in ["mile_oval","texas","michigan"]:
		root.set_meta("roster_selection",{"track_id":track_id,"file":"res://content/rosters/icr2_test/manifest.json","seed":42,"ai_telemetry":false})
		var main = load("res://game/main/main.tscn").instantiate()
		root.add_child(main)
		main.process_mode = Node.PROCESS_MODE_DISABLED
		var driver = main.ai_cars[0].get_node("Driver")
		driver.mode = driver.Mode.RACING
		var craft = driver.racecraft
		for start in [0,driver.race.size()/3,driver.race.size()-1]:
			driver.index = start
			for launch in [0.0,.4,1.0]:
				craft.launch_weight = launch
				craft.launch_lateral_m = 3.5
				for lane in [-1.0,-.3,0.0,.7,1.0]:
					craft.lane = lane
					craft.own = Vector2(0,lane*4)
					for gap in [0.0,8.9,12.5,17.99,18.0]:
						craft.nearby.assign([{"car":main.ai_cars[1],"gap":gap,"lateral":-1.4},{"car":main.ai_cars[1],"gap":-gap,"lateral":1.7}])
						var samples: PackedVector3Array = craft.planner_samples(driver,80)
						for i in range(samples.size()):
							var distance := float(i*5-25)
							var expected := original(driver,distance)
							max_error = maxf(max_error,samples[i].distance_to(expected))
							max_error = maxf(max_error,craft.ahead(driver,distance).distance_to(expected))
							cases += 1
		main.free()
	print("SIDE ROOM EQUIVALENCE cases=",cases," max_error_m=",max_error)
	quit(0 if max_error < .0001 else 1)
