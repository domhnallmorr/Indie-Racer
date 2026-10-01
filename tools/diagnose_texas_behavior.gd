extends SceneTree
## Headless observer: --fixed-fps 60 --script tools/diagnose_texas_behavior.gd
## User arguments: --seed=42 --seconds=180 --tag=baseline [--clean-air]
## Captures completed physics-step state before the following driver update.

func _initialize() -> void:
	call_deferred("measure")

func option(key: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--"+key+"="):
			return argument.substr(key.length()+3)
	return fallback

func measure() -> void:
	Engine.physics_ticks_per_second = 60
	var seed_value := int(option("seed","42"))
	var duration := int(option("seconds","180"))
	var tag := option("tag","baseline").validate_filename()
	var clean := "--clean-air" in OS.get_cmdline_user_args()
	var directory := "res://builds/texas_behavior/"+tag
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory+"/trace.csv",FileAccess.WRITE)
	if file == null:
		push_error("Could not create diagnostic output")
		quit(1)
		return
	file.store_line("tick,time_s,car,mode,speed_mps,profile_mps,request_mps,reason,state,lane,target_lane,blocked,opponent,attempts,passes,aborts,line_error_m,progress_m,lateral_m,target_lateral_m,raw_target_lateral_m,side_correction_m,nearest_car,nearest_gap_m,nearest_lateral_m,nearest_speed_mps,opponent_gap_m,launch_weight,yield_s,contact,x_m,z_m,yaw_rad,tow_fraction,fuel_gal,session_status,race_control_phase")
	root.set_meta("roster_selection",{"track_id":"texas","file":"res://content/rosters/irl_2001/manifest.json","seed":seed_value,"session_mode":"race","race_laps":30})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.player.global_transform = main.player.track.global_transform*main.track_data.pit_box_transform()
	main.player.reset_dynamics()
	main.player.telemetry.stop()
	var wall_events: Array = []
	for car in main.ai_cars:
		# Isolate green-flag driving from seeded mechanical retirements.
		car.get_node("Driver").race_plan.failure_progress = INF
		car.wall_impact.connect(func(impact: Dictionary):
			var event := impact.duplicate()
			event["car"] = str(car.name)
			event["driver_elapsed_s"] = car.get_node("Driver").elapsed
			var collider = instance_from_id(impact.collider_id)
			event["collider_path"] = str(collider.get_path()) if is_instance_valid(collider) else "freed"
			wall_events.append(event)
		)
	var green := -1
	var contacts := 0
	var edge_ticks := 0
	var max_offset := 0.0
	var started := Time.get_ticks_msec()
	for tick in range((duration+180)*60):
		await physics_frame
		if green < 0:
			if main.session.status != main.session.Status.RUNNING:
				continue
			green = tick
			if clean:
				for car in main.ai_cars:
					car.get_node("Driver").rivals.clear()
					car.collision_layer = 0
					car.collision_mask = 1
			print("TEXAS BEHAVIOR green seed=",seed_value," tag=",tag," formation_s=",tick/60.0)
		var race_tick := tick-green
		for car in main.ai_cars:
			var driver = car.get_node("Driver")
			var craft = driver.racecraft
			var coordinates: Vector2 = craft.coordinates(driver,car)
			var position: Vector3 = car.track.to_local(car.global_position)
			var closest := Geometry3D.get_closest_point_to_segment(position,driver.race[driver.index],driver.race[(driver.index+1)%driver.race.size()])
			var origin: float = closest.distance_to(driver.race[driver.index])
			var distance: float = origin+clampf(4.0+car.speed_mps*.22,5,22)
			var raw: Vector3 = craft.path_point(driver,distance,craft.lane)
			if craft.launch_weight > 0.0:
				raw = raw.lerp(craft.track_lane_point(driver,distance,craft.launch_lateral_m),craft.launch_weight)
			var protected: Vector3 = craft.ahead(driver,distance)
			var at: float = fposmod(driver.race_distances[driver.index]+distance,driver.race_length_m)
			var low: Vector3 = driver._sample_path(craft.inner,driver.race_distances,at)
			var high: Vector3 = driver._sample_path(craft.outer,driver.race_distances,at)
			var across := high-low
			var target_lateral: float = (protected-low).dot(across)/maxf(across.length_squared(),.001)*16.0-8.0
			var raw_lateral: float = (raw-low).dot(across)/maxf(across.length_squared(),.001)*16.0-8.0
			var nearest := ""
			var nearest_gap := 9999.0
			var nearest_lateral := 0.0
			var nearest_speed := 0.0
			var opponent_gap := 9999.0
			for other in craft.nearby:
				if absf(other.gap) < absf(nearest_gap):
					nearest = str(other.car.name)
					nearest_gap = other.gap
					nearest_lateral = other.lateral
					nearest_speed = other.car.speed_mps
				if other.car == craft.opponent:
					opponent_gap = other.gap
			if car.car_contact_this_step:
				contacts += 1
			max_offset = maxf(max_offset,absf(coordinates.y))
			if absf(coordinates.y) > 9.0:
				edge_ticks += 1
			var values: Array = [race_tick,race_tick/60.0,str(car.name),driver.mode,car.speed_mps,driver.profile_speed,driver.requested_speed,driver.traffic_reason,craft.state,craft.lane,craft.target_lane,int(craft.lane_change_blocked),str(craft.opponent.name) if is_instance_valid(craft.opponent) else "",craft.attempts,craft.passes,craft.aborted,driver.current_line_error,coordinates.x,coordinates.y,target_lateral,raw_lateral,target_lateral-raw_lateral,nearest,nearest_gap,nearest_lateral,nearest_speed,opponent_gap,craft.launch_weight,craft.yield_remaining_s,int(car.car_contact_this_step),position.x,position.z,car.rotation.y,car.slipstream_speed_fraction,car.player_state.fuel_gal,main.session.status,main.race_control.phase]
			var row := PackedStringArray()
			for value in values:
				row.append(str(value))
			file.store_csv_line(row)
		if race_tick % 1800 == 0:
			file.flush()
			print("TEXAS BEHAVIOR seconds=",race_tick/60.0," contacts=",contacts," edge_ticks=",edge_ticks)
		if race_tick >= duration*60:
			break
	file.close()
	var cars: Array = []
	for car in main.ai_cars:
		var craft = car.get_node("Driver").racecraft
		cars.append({"car":str(car.name),"name":str(car.get_meta("driver_name",car.name)),"attempts":craft.attempts,"passes":craft.passes,"aborts":craft.aborted})
	var result := {"seed":seed_value,"seconds":duration,"clean_air":clean,"failures_disabled":true,"player_parked":true,"green":green>=0,"green_time_s":green/60.0,"contacts":contacts,"edge_ticks":edge_ticks,"max_offset_m":max_offset,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"wall_events":wall_events,"cars":cars}
	var summary := FileAccess.open(directory+"/summary.json",FileAccess.WRITE)
	summary.store_string(JSON.stringify(result,"  "))
	summary.close()
	print("TEXAS BEHAVIOR RESULT ",JSON.stringify(result))
	main.free()
	quit(0 if green >= 0 else 1)
