extends SceneTree
## Fixed-position CPU comparison: no render or lap-timing noise.
func _initialize() -> void:
	call_deferred("profile")

func profile() -> void:
	var results: Array = []
	for track_id in ["mile_oval","texas"]:
		root.set_meta("roster_selection",{"track_id":track_id,"file":"res://content/rosters/irl_2001/manifest.json","seed":1234})
		var main = load("res://game/main/main.tscn").instantiate()
		root.add_child(main)
		main.player.driving_enabled = false
		var fixture = preload("res://tools/validate_racecraft.gd").new()
		for i in range(main.ai_cars.size()):
			var car = main.ai_cars[i]
			var driver = car.get_node("Driver")
			driver.set_physics_process(false)
			fixture.place(car,100.0+i*15.0,0.0,80.0)
			car.update_zone_state()
		await physics_frame
		var item := {"track":track_id,"cars":main.ai_cars.size(),"path_points":main.ai_cars[0].get_node("Driver").race.size()}
		for tow in [false,true]:
			for car in main.ai_cars:
				car.slipstream_speed_fraction = .05 if tow else 0.0
			var start := Time.get_ticks_usec()
			for repeat in range(60):
				for car in main.ai_cars:
					car.get_node("Driver")._planned_speed()
			item["planner_tow_ms" if tow else "planner_clean_ms"] = (Time.get_ticks_usec()-start)/60000.0
		for operation in ["sample","zones"]:
			var start := Time.get_ticks_usec()
			for repeat in range(60):
				for car in main.ai_cars:
					if operation == "sample":
						preload("res://game/vehicle/slipstream.gd").sample(car)
					else:
						car.update_zone_state()
			item[operation+"_ms"] = (Time.get_ticks_usec()-start)/60000.0
		print("SLIPSTREAM PROFILE ",JSON.stringify(item))
		results.append(item)
		fixture.free()
		main.free()
		await process_frame
	var file := FileAccess.open("res://builds/slipstream_profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	quit()
