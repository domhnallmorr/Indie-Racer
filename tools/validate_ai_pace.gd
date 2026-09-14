extends SceneTree
## Seeded clean-air pace measurement, using the real car and timing gates.
## Opponents are ghosts only in this fixture; full-field validation covers traffic.
func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	Engine.physics_ticks_per_second = 480
	Engine.time_scale = 8
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_seed = 1234
	if "--reference" in OS.get_cmdline_user_args():
		main.roster_file = "res://content/rosters/default/manifest.json"
	root.add_child(main)
	var fixture = load("res://tools/validate_racecraft.gd").new()
	var samples: Array = []
	var offsets: Array[float] = []
	for car in main.ai_cars:
		var driver = car.get_node("Driver")
		if "--capture" in OS.get_cmdline_user_args():
			driver.diagnostic = FileAccess.open("res://builds/pace_"+str(car.name)+".csv",FileAccess.WRITE)
			driver.diagnostic.store_csv_line(driver.DIAGNOSTIC_HEADER.split(","))
		assert(driver.racecraft.enabled,"Pace calibration requires a valid racing corridor")
		assert(car.parameters.values == main.player.parameters.values,"Pace must use shared vehicle physics")
		driver.rivals.clear()
		car.collision_layer = 0
		fixture.place(car,100,0,65)
		samples.append([])
		offsets.append(0.0)
	for tick in range(9000):
		await physics_frame
		if tick % 1800 == 1799:
			print("PACE seconds=",(tick+1)/60," leader best=",main.lap_timing.entries[1].best)
		for i in range(main.ai_cars.size()):
			var car = main.ai_cars[i]
			var driver = car.get_node("Driver")
			var entry: Dictionary = main.lap_timing.entries[i+1]
			if entry.laps > samples[i].size():
				samples[i].append(entry.last)
			offsets[i] = maxf(offsets[i],absf(driver.racecraft.coordinates(driver,car).y))
	var results: Array = []
	var failures := 0
	for i in range(main.ai_cars.size()):
		var entry: Dictionary = main.lap_timing.entries[i+1]
		var laps: Array = samples[i].slice(1)
		var total := 0.0
		for lap in laps:
			total += lap
		var item := {"name":entry.name,"utilisation":main.ai_cars[i].get_node("Driver").cornering_utilisation,"best":entry.best,"mean":total/maxi(1,laps.size()),"laps":laps,"max_road_offset":offsets[i]}
		results.append(item)
		print(JSON.stringify(item))
		if laps.size() < 3 or offsets[i] > 9 or item.mean < 21.5 or item.mean > 23.2:
			failures += 1
	var file := FileAccess.open("res://builds/ai_pace_reference.json" if "--reference" in OS.get_cmdline_user_args() else "res://builds/ai_pace_tuned.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	file.close()
	fixture.free()
	print("AI PACE PASSED" if failures == 0 else "AI PACE FAILED")
	quit(0 if failures == 0 else 1)
