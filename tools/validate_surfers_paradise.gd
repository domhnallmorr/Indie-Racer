extends SceneTree
## Real pit departures, ordered timing gates, collisions, service and rejoin.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	# Scheduling uses physics-frame counts: changing tick rate and time scale
	# together would silently turn 60 Hz planning into 7.5 Hz simulation updates.
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1
	var race_mode := "--race" in OS.get_cmdline_user_args()
	var full_field := "--field" in OS.get_cmdline_user_args()
	var immediate_green := "--green" in OS.get_cmdline_user_args()
	var baseline := "--baseline" in OS.get_cmdline_user_args()
	var seconds := 660 if race_mode and not immediate_green else 420
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			seconds = maxi(120,int(arg.trim_prefix("--seconds=")))
	root.set_meta("roster_selection",{"track_id":"surfers_paradise","file":"res://content/rosters/irl_2001/manifest.json" if full_field else "res://content/rosters/icr2_test/manifest.json","seed":42,"session_mode":"race" if race_mode else "practice","incident_mode":"off","race_laps":10,"ai_telemetry":false})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	var circuit: Node3D = main.get_node("MileOval")
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/surfers_paradise/ai/race_line.json"))
	for i in range(0,profile.points.size()-1,12):
		var p: Array = profile.points[i]
		var at := circuit.to_global(Vector3(p[0],0,p[2]))
		var hit := root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*3,at-Vector3.UP,1))
		if hit.is_empty() or absf(hit.position.y)>.06:
			failures.append("Missing road at "+str(i))
	for car in main.ai_cars:
		var driver = car.get_node("Driver")
		if not race_mode:
			driver.release_delay = main.ai_cars.find(car)*8.0
		if not driver.profile_ready or not driver.racecraft.enabled or not driver.racecraft.physical_corridor_width:
			failures.append("Invalid driver/corridor "+str(car.name))
		if baseline and not driver.tactical_speeds.is_empty():
			# Compare the same traffic fixture against the previous conservative
			# speed plan, preserving relative roster pace and fuel calibration.
			var old_lap := 0.0
			for i in range(driver.race.size()-1):
				old_lap += 2.0*driver.race[i].distance_to(driver.race[i+1])/(driver.tactical_speeds[i]+driver.tactical_speeds[i+1])
			driver.base_lap_target_s *= old_lap/driver.reference_lap_s
			driver.reference_lap_s = old_lap
			driver.reference_speeds = driver.tactical_speeds.duplicate()
			driver.reference_min_speed = INF
			driver.reference_peak_speed = 0.0
			for speed in driver.reference_speeds:
				driver.reference_min_speed = minf(driver.reference_min_speed,speed)
				driver.reference_peak_speed = maxf(driver.reference_peak_speed,speed)
			driver._cache_tow_profile()
	if not failures.is_empty():
		print("SURFERS FAIL ",failures)
		main.free()
		quit(1)
		return
	if race_mode:
		# Allow AI pole to bring the field to green; keep the unattended player clear.
		main.player.global_transform = circuit.global_transform*main.track_data.pit_box_transform(0)
		main.player.reset_dynamics()
		if immediate_green:
			# Focused traffic regression after separately verifying formation.
			main.pace_car.set_physics_process(false)
			main.pace_car.phase = main.pace_car.Phase.PARKED
			main.pace_car.global_transform = circuit.global_transform*main.track_data.pace_car_box
			main.session.show_green()
	var max_error := 0.0
	var wall_ticks := 0
	var reported_error := 0.0
	for tick in range(60*seconds):
		await physics_frame
		for car in main.ai_cars:
			var driver = car.get_node("Driver")
			if driver.mode == driver.Mode.RACING:
				max_error = maxf(max_error,driver.current_line_error)
				if driver.current_line_error>maxf(3,reported_error+1):
					reported_error = driver.current_line_error
					print("SURFERS tracking ",car.name," index ",driver.index," error ",driver.current_line_error," position ",car.position," lane ",driver.racecraft.lane)
			for j in range(car.get_slide_collision_count()):
				if absf(car.get_slide_collision(j).get_normal().y)<.5:
					wall_ticks += 1
					if wall_ticks<5:
						print("SURFERS contact ",car.name," mode ",driver.mode," index ",driver.index," with ",car.get_slide_collision(j).get_collider().get_parent().name)
		if tick%3600==3599:
			var states := []
			for car in main.ai_cars:
				var driver = car.get_node("Driver")
				states.append([car.name,driver.mode,driver.index,snappedf(car.speed_mps*3.6,.1),driver.laps])
			print("SURFERS ",tick/60+1," s ",states)
	var laps := []
	for entry in main.lap_timing.entries.slice(1):
		laps.append({"name":entry.name,"laps":entry.laps,"best":entry.best})
		if entry.laps < 1:
			failures.append("No timed lap: "+entry.name)
	if max_error>3:
		failures.append("Excessive racing error "+str(max_error))
	if wall_ticks>0:
		failures.append("Wall/car contacts "+str(wall_ticks))
	var served := false
	var rejoined := false
	if not full_field:
		var driver = main.ai_cars[0].get_node("Driver")
		driver._begin_pit_entry()
		for tick in range(60*240):
			await physics_frame
			served = served or driver.completed_fuel_stops>0 or driver.completed_stints>0
			if served and not race_mode and driver.mode == driver.Mode.WAITING:
				driver.release_delay = driver.elapsed
			if served and driver.mode == driver.Mode.RACING:
				rejoined = true
				break
			if tick%3600==3599:
				print("SURFERS pit ",driver.mode," index ",driver.index," speed ",main.ai_cars[0].speed_mps*3.6)
		if not rejoined:
			failures.append("Pit service/rejoin failed")
	print("SURFERS VALIDATION ",JSON.stringify({"failures":failures,"laps":laps,"max_error_m":max_error,"wall_ticks":wall_ticks,"served":served,"rejoined":rejoined,"race":race_mode,"field":full_field,"immediate_green":immediate_green}))
	main.free()
	quit(0 if failures.is_empty() else 1)
