extends SceneTree
## Compare the same seeded race grid with and without traffic interaction.
func _initialize() -> void:
	call_deferred("measure")

func measure() -> void:
	Engine.physics_ticks_per_second = 480
	Engine.time_scale = 8
	var ghost := "--clean-air" in OS.get_cmdline_user_args()
	root.set_meta("roster_selection",{"file":"res://content/rosters/icr2_full/manifest.json","seed":1234,"session_mode":"race"})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	# The unattended player must not become a stationary obstacle on the grid.
	main.player.global_transform = main.get_node("MileOval").global_transform*main.track_data.pit_box_transform()
	main.player.reset_dynamics()
	var counts: Array = []
	for car in main.ai_cars:
		counts.append({"collision_guard":0,"racing":0,"states":{}})
	# Let the normal formation lap establish the racing entry and timing gates.
	for tick in range(7200):
		await physics_frame
		if main.session.status == main.session.Status.RUNNING:
			break
	if main.session.status != main.session.Status.RUNNING:
		push_error("Formation did not reach green")
		quit(1)
		return
	if ghost:
		for car in main.ai_cars:
			car.get_node("Driver").rivals.clear()
			car.collision_layer = 0
			car.collision_mask = 1
	for tick in range(9000):
		await physics_frame
		for i in range(main.ai_cars.size()):
			var driver = main.ai_cars[i].get_node("Driver")
			counts[i].racing += 1
			if driver.traffic_reason.begins_with("collision_guard"):
				counts[i].collision_guard += 1
			var state: String = driver.racecraft.state
			counts[i].states[state] = counts[i].states.get(state,0)+1
		if tick % 1800 == 1799:
			print("PACE DIAGNOSTIC clean_air=",ghost," seconds=",(tick+1)/60)
	var results: Array = []
	for i in range(main.ai_cars.size()):
		var car = main.ai_cars[i]
		var entry: Dictionary = main.lap_timing.entries[i+1]
		var craft = car.get_node("Driver").racecraft
		results.append({"name":entry.name,"target":car.get_meta("roster_entry").icr2_lap_s,"best":entry.best,"last":entry.last,"laps":entry.laps,"collision_guard_fraction":float(counts[i].collision_guard)/counts[i].racing,"states":counts[i].states,"attempts":craft.attempts,"passes":craft.passes,"aborts":craft.aborted})
	var output := "res://builds/diagnostic_clean_air.json" if ghost else "res://builds/diagnostic_race_traffic.json"
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	file.close()
	print(JSON.stringify(results))
	main.free()
	quit()
