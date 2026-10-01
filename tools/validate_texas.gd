extends SceneTree
## Texas integration probe: surface banks, full-field circulation and pit return.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	Engine.physics_ticks_per_second = 480
	Engine.time_scale = 8
	root.set_meta("roster_selection",{"track_id":"texas","file":"res://content/rosters/irl_2001/manifest.json","seed":42,"session_mode":"practice"})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	if main.ai_cars.size() != 18:
		failures.append("Expected 18 AI cars")
	var circuit: Node3D = main.get_node("MileOval")
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/texas/ai/reference_paths.json"))
	# Probe the apex plateaus; the old locations now lie on the longer ramps.
	for sample in [[333,20.0],[874,24.0]]:
		var p: Array = reference.reference_path[sample[0]]
		var at := circuit.to_global(Vector3(p[0],p[1],p[2]))
		var hit := root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*10,at-Vector3.UP*10,1))
		if hit.is_empty():
			failures.append("Missing track collision")
		else:
			var angle := rad_to_deg(acos(clampf(hit.normal.y,-1,1)))
			print("BANK ",sample[0]," = ",angle)
			if absf(angle-sample[1]) > .2:
				failures.append("Bank mismatch")
	for i in range(main.ai_cars.size()):
		var driver = main.ai_cars[i].get_node("Driver")
		driver.release_delay = i*2.5
		driver.stint_laps = 100
		if not driver.profile_ready or not driver.racecraft.enabled:
			failures.append("Invalid AI profile/corridor")
	if not failures.is_empty():
		print(failures)
		quit(1)
		return
	var peak := 0.0
	var lost_floor := 0
	var limiter_errors := 0
	var worst_error := 0.0
	var outside_road_ticks := 0
	var outside_examples: Array = []
	for tick in range(12000):
		await physics_frame
		for car in main.ai_cars:
			var driver = car.get_node("Driver")
			peak = maxf(peak,car.speed_mps*3.6)
			if driver.mode == 2:
				worst_error = maxf(worst_error,driver.current_line_error)
				if not car.is_on_floor():
					lost_floor += 1
				var local: Vector3 = circuit.to_local(car.global_position)
				var inner: Vector3 = driver.racecraft.inner[driver.index]
				var outer: Vector3 = driver.racecraft.outer[driver.index]
				var across := outer-inner
				across.y = 0
				var offset := (local-inner).dot(across.normalized())
				if offset < -1.5 or offset > across.length()+1.5:
					outside_road_ticks += 1
					if outside_examples.size() < 8 and tick%5 == 0:
						outside_examples.append({"time":tick/60.0,"car":car.name,"index":driver.index,"offset":offset,"position":str(local),"speed":car.speed_mps*3.6,"line_error":driver.current_line_error})
						print("TEXAS boundary ",outside_examples[-1])
			if car.player_state.is_in_pit_speed_zone and car.speed_mps*3.6 > 80.1:
				limiter_errors += 1
		if tick%3600 == 3599:
			print("TEXAS seconds=",(tick+1)/60," leader_laps=",main.lap_timing.entries[1].laps," peak_kph=",peak)
	var results: Array = []
	for entry in main.lap_timing.entries.slice(1):
		var driver = entry.car.get_node("Driver")
		results.append({"name":entry.name,"laps":entry.laps,"best_s":entry.best,"mode":driver.mode,"error_m":driver.current_line_error})
		if entry.laps < 3:
			failures.append("Insufficient laps: "+entry.name)
	if lost_floor > 0 or limiter_errors > 0 or outside_road_ticks > 0:
		failures.append("Grounding, road boundary or limiter failures")
	var report := {"results":results,"peak_kph":peak,"lost_floor_ticks":lost_floor,"outside_road_ticks":outside_road_ticks,"outside_examples":outside_examples,"limiter_errors":limiter_errors,"max_line_error_m":worst_error,"failures":failures}
	var file := FileAccess.open("res://builds/texas_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify(report))
	main.free()
	quit(0 if failures.is_empty() else 1)
