extends SceneTree
var failures: Array[String] = []
var frame_times: Array[float] = []
var frame_last_usec := 0
var frame_start_usec := 0
var live_windows: Array = []
var live_physics_ms := 0.0

func record_frame() -> void:
	var now := Time.get_ticks_usec()
	if now-frame_start_usec > 2000000 and frame_last_usec > 0:
		frame_times.append((now-frame_last_usec)/1000.0)
		live_physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
	frame_last_usec = now

func report_frames(seconds: float) -> void:
	if frame_times.is_empty():
		return
	frame_times.sort()
	var item := {"sim_seconds":seconds,"frames":frame_times.size(),"median_frame_ms":frame_times[frame_times.size()/2],"p95_frame_ms":frame_times[int(frame_times.size()*.95)],"physics_ms":live_physics_ms/frame_times.size()}
	live_windows.append(item)
	print("LIVE FRAMES ",JSON.stringify(item))
	frame_times.clear()
	live_physics_ms = 0
func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var realtime := "--realtime" in OS.get_cmdline_user_args()
	Engine.physics_ticks_per_second = 60 if realtime else 480
	Engine.time_scale = 1 if realtime else 8
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_file = "res://content/rosters/club_1996/manifest.json"
	main.roster_seed = 1234
	root.add_child(main)
	if realtime:
		main.get_node("DisplayCar/Cockpit").deactivate()
		var view = main.get_node("InspectionCamera")
		view.followed_ai = 0
		view.distance = 18
		view.make_current()
		frame_start_usec = Time.get_ticks_usec()
		process_frame.connect(record_frame)
	if main.ai_cars.size() != 15 or main.track_data.pit_boxes.size() != 16:
		push_error("Expected 15 AI and 16 pit boxes")
		quit(1)
		return
	var boxes := {}
	var minimum := INF
	var maximum := 0.0
	for car in main.ai_cars:
		var id: String = car.player_state.assigned_pit_box_id
		if boxes.has(id) or not main.track_data.contains_pit_lane(car.track.to_local(car.global_position)):
			failures.append("Invalid/duplicate pit assignment: "+id)
		boxes[id] = true
		var driver = car.get_node("Driver")
		minimum = minf(minimum,driver.cornering_utilisation)
		maximum = maxf(maximum,driver.cornering_utilisation)
		if driver.diagnostic != null:
			driver.diagnostic.close()
			driver.diagnostic = null
	if maximum-minimum < .015:
		failures.append("Insufficient performance spread")
	var camera = main.get_node("InspectionCamera")
	camera.followed_ai = 14
	var event := InputEventKey.new()
	event.keycode = KEY_7
	event.pressed = true
	camera._unhandled_input(event)
	if camera.followed_ai != 0:
		failures.append("Camera did not wrap through field")
	var following := false
	var joined := {}
	var slowest_join := INF
	var clear_merge_stops := 0
	var merge_only := "--merge-only" in OS.get_cmdline_user_args()
	var gate_stops := {}
	var racing_contacts := 0
	var racing_edge_ticks := 0
	var passing_attempts := 0
	var completed_passes := 0
	var maximum_road_offset := 0.0
	for tick in range(18000):
		await physics_frame
		for car in main.ai_cars:
			var driver = car.get_node("Driver")
			if driver.mode == 2 and driver.racecraft.enabled:
				var track_position: Vector2 = driver.racecraft.coordinates(driver,car)
				if absf(track_position.y) > maximum_road_offset:
					maximum_road_offset = absf(track_position.y)
					if maximum_road_offset > 8.5:
						print("Road margin %s t=%.2f offset=%.2f state=%s lane=%.2f/%.2f speed=%.1f" % [car.name,driver.elapsed,track_position.y,driver.racecraft.state,driver.racecraft.lane,driver.racecraft.target_lane,car.speed_mps*3.6])
				if absf(track_position.y) > 9:
					racing_edge_ticks += 1
				for collision in range(car.get_slide_collision_count()):
					if car.get_slide_collision(collision).get_collider() in main.ai_cars:
						racing_contacts += 1
						if racing_contacts == 1:
							var other = car.get_slide_collision(collision).get_collider()
							print("FIRST CONTACT t=",driver.elapsed," cars=",car.name,"/",other.name," states=",driver.racecraft.state,"/",other.get_node("Driver").racecraft.state," positions=",driver.racecraft.coordinates(driver,car),"/",driver.racecraft.coordinates(driver,other))
			if driver.mode == 1 and driver.route_distances[driver.index] > driver.merge_gate_m-100 and car.speed_mps < 5:
				var reason: String = driver.traffic_reason
				gate_stops[reason] = gate_stops.get(reason,0)+1
			if driver.mode == 2 and not joined.has(car.name):
				joined[car.name] = true
				slowest_join = minf(slowest_join,car.speed_mps*3.6)
				print("Joined %s: %.1f km/h at %.1f s" % [car.name,car.speed_mps*3.6,driver.elapsed])
			if driver.mode == 1 and driver.merge_committed and car.track.to_local(car.global_position).z < -120 and driver.traffic_reason == "clear" and car.speed_mps < 5:
				clear_merge_stops += 1
			following = following or driver.traffic_reason.begins_with("following_")
			if car.player_state.is_in_pit_speed_zone and car.speed_mps > 80.0/3.6+.01:
				if not "Pit limiter exceeded" in failures:
					failures.append("Pit limiter exceeded")
		if tick % 3600 == 3599:
			if realtime:
				report_frames((tick+1)/60.0)
			var racing := 0
			for car in main.ai_cars:
				if car.get_node("Driver").mode == 2:
					racing += 1
			print("Full field: %.0f s, %d/15 racing" % [(tick+1)/60.0,racing])
			for car in main.ai_cars:
				var driver = car.get_node("Driver")
				if driver.mode != 2:
					print("Pending %s: mode=%d index=%d speed=%.1f reason=%s position=%s" % [car.name,driver.mode,driver.index,car.speed_mps*3.6,driver.traffic_reason,car.track.to_local(car.global_position)])
		if merge_only and joined.size() == 15:
			break
	for i in range(main.ai_cars.size()):
		var car = main.ai_cars[i]
		var driver = car.get_node("Driver")
		var timing: Dictionary = main.lap_timing.entries[i+1]
		passing_attempts += driver.racecraft.attempts
		completed_passes += driver.racecraft.passes
		print("%s: laps=%d best=%.3f max_line_error=%.2f" % [timing.name,timing.laps,timing.best,driver.max_line_error_m])
		if driver.mode != 2 or (not merge_only and timing.laps < 2):
			failures.append(timing.name+" did not join and complete two timed laps")
	if not following:
		failures.append("Field never exercised traffic following")
	if clear_merge_stops > 0:
		failures.append("Unobstructed AI stopped during committed merge")
	print("Merge summary: slowest join %.1f km/h; unobstructed stop ticks %d" % [slowest_join,clear_merge_stops])
	print("All end-of-exit stop ticks, including before commitment: ",gate_stops)
	print("Racing: attempts=%d completed=%d contact_ticks=%d outside_corridor_ticks=%d" % [passing_attempts,completed_passes,racing_contacts,racing_edge_ticks])
	print("Maximum road-centre offset: %.3f m" % maximum_road_offset)
	if not merge_only and (completed_passes == 0 or racing_contacts > 0 or racing_edge_ticks > 0):
		failures.append("Full-field racecraft failed: passes, contact or road clearance")
	for failure in failures:
		push_error(failure)
	print("FULL FIELD PASSED" if failures.is_empty() else "FULL FIELD FAILED")
	if realtime:
		var output := FileAccess.open("res://builds/racecraft_live_soak.json",FileAccess.WRITE)
		output.store_string(JSON.stringify(live_windows,"  "))
		output.close()
	quit(0 if failures.is_empty() else 1)
