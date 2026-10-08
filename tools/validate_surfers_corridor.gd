extends SceneTree
## Project cars on both passing paths through actual left/right chicanes.
func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	root.set_meta("roster_selection",{"track_id":"surfers_paradise","file":"res://content/rosters/icr2_test/manifest.json","seed":42,"ai_telemetry":false})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var car = main.ai_cars[0]
	var driver = car.get_node("Driver")
	var craft = driver.racecraft
	driver.mode = driver.Mode.RACING
	craft.launch_weight = 0
	craft.nearby.clear()
	var max_error := 0.0
	# Sample actual bends in the current source, not the previous stock indices.
	var corners: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/surfers_paradise/ai/corner_regions.json"))
	var samples: Array[int] = []
	var protected_samples: Array[int] = []
	for region in corners.regions:
		var low := INF
		var high := -INF
		var low_at := int(region.entry_index)+1
		var high_at := low_at
		for at in range(int(region.entry_index)+1,int(region.exit_index)):
			var before: Vector3 = (driver.race[at]-driver.race[at-1]).normalized()
			var after: Vector3 = (driver.race[at+1]-driver.race[at]).normalized()
			var bend := before.cross(after).y
			if bend<low:
				low = bend
				low_at = at
			if bend>high:
				high = bend
				high_at = at
		for at in [low_at,high_at]:
			if not samples.has(at): samples.append(at)
		protected_samples.append(low_at if absf(low)>absf(high) else high_at)
	for lane in [-1.0,0.0,1.0]:
		craft.lane = lane
		for at in samples:
			driver.index = at-2
			var point: Vector3 = driver.race[at]
			if lane<0: point = craft.inside[at]
			if lane>0: point = craft.outside[at]
			car.global_position = car.track.to_global(point+Vector3.UP*.025)
			driver._update_index(point)
			driver._sample_steering_curvature(point)
			max_error = maxf(max_error,driver.current_line_error)
			assert(driver.index == at,"Progress must follow the selected path through a chicane")
			assert(driver.current_line_error<.001,"A car on its passing line must not report a RACE projection error")
			var middle: Vector3 = (craft.inner[at]+craft.outer[at])*.5
			var across: Vector3 = (craft.outer[at]-craft.inner[at]).normalized()
			var formation: Vector3 = craft.track_lane_point(driver,0,2.0)
			assert(formation.distance_to(middle+across*2.0)<.001,"Formation spacing must use real metres")
	# Keep a neighbour alongside and put the car on the resulting protected
	# path. Side-room corrections must share the same progress coordinate.
	craft.lane = 0.0
	craft.own.y = 1.0
	craft.nearby.assign([{"car":main.ai_cars[1],"gap":0.0,"lateral":-2.0}])
	for at in protected_samples:
		driver.index = at
		var protected: Vector3 = craft.ahead(driver,0)
		car.global_position = car.track.to_global(protected+Vector3.UP*.025)
		driver._update_index(protected)
		driver._sample_steering_curvature(protected)
		assert(driver.current_line_error<.01,"Alongside room must be included in progress projection")
	print("SURFERS CORRIDOR PASS: ",samples.size()*3," left/right bend path projections and physical formation offsets; max error ",max_error)
	main.free()
	quit()
