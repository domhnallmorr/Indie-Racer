extends SceneTree
var frame_times: Array[float] = []
var record_frames := false
var last_frame_usec := 0

class ReplayPlayer extends "res://game/vehicle/player_bicycle.gd":
	var replay_inputs: Array[Vector3] = []
	var replay_positions: Array[Vector3] = []
	var replay_index := 0
	var replay_max_error_m := 0.0
	func load_replay(path: String) -> void:
		var file := FileAccess.open(path,FileAccess.READ)
		assert(file != null,"Cannot read replay telemetry")
		var header := file.get_csv_line()
		while not file.eof_reached():
			var row := file.get_csv_line()
			if row.size() != header.size():
				continue
			replay_inputs.append(Vector3(float(row[header.find("throttle_input")]),float(row[header.find("brake_input")]),float(row[header.find("steering_input")])))
			replay_positions.append(Vector3(float(row[header.find("track_x_m")]),float(row[header.find("track_y_m")]),float(row[header.find("track_z_m")])))
		assert(not replay_inputs.is_empty())
	func _physics_process(delta: float) -> void:
		if replay_index >= replay_inputs.size():
			return
		var controls := replay_inputs[replay_index]
		drive_step(delta,controls.x,controls.y,controls.z)
		replay_max_error_m = maxf(replay_max_error_m,track.to_local(global_position).distance_to(replay_positions[replay_index]))
		replay_index += 1

func sample_frame() -> void:
	var now := Time.get_ticks_usec()
	if record_frames and last_frame_usec > 0:
		frame_times.append((now-last_frame_usec)/1000.0)
	last_frame_usec = now

class TimedRacecraft extends "res://game/ai/racecraft.gd":
	var costs := {"racecraft":0,"projection":0,"side_room":0,"ticks":0}
	func update(driver, delta: float) -> void:
		var start := Time.get_ticks_usec()
		super.update(driver,delta)
		costs.racecraft += Time.get_ticks_usec()-start
		costs.ticks += 1
	func coordinates(driver, vehicle: Node3D) -> Vector2:
		var start := Time.get_ticks_usec()
		var value := super.coordinates(driver,vehicle)
		costs.projection += Time.get_ticks_usec()-start
		return value
	func _apply_side_room(driver, distance: float, point: Vector3, bounds: Vector3) -> Vector3:
		var start := Time.get_ticks_usec()
		var value := super._apply_side_room(driver,distance,point,bounds)
		costs.side_room += Time.get_ticks_usec()-start
		return value
class TimedDriver extends "res://game/ai/icr2_driver.gd":
	var costs := {"total":0,"planner":0,"traffic":0,"index":0,"collisions":0,"ticks":0}
	func _update_car_collisions() -> void:
		var start := Time.get_ticks_usec()
		super._update_car_collisions()
		costs.collisions += Time.get_ticks_usec()-start
	func _physics_process(delta: float) -> void:
		var start := Time.get_ticks_usec()
		super._physics_process(delta)
		if practice_session.status == practice_session.Status.RUNNING:
			costs.total += Time.get_ticks_usec()-start
			costs.ticks += 1
	func _planned_speed() -> float:
		var start := Time.get_ticks_usec()
		var value := super._planned_speed()
		costs.planner += Time.get_ticks_usec()-start
		return value
	func _traffic_speed(request: float) -> float:
		var start := Time.get_ticks_usec()
		var value := super._traffic_speed(request)
		costs.traffic += Time.get_ticks_usec()-start
		return value
	func _update_index(position: Vector3) -> void:
		var start := Time.get_ticks_usec()
		super._update_index(position)
		costs.index += Time.get_ticks_usec()-start

class TimedCar extends "res://game/vehicle/icr2_car.gd":
	var costs := {"movement":0,"tow":0,"zones":0,"grounding":0,"contacts":0,"steps":0,"ticks":0}
	func _try_surface_step(motion: Vector3) -> void:
		var start := Time.get_ticks_usec()
		super._try_surface_step(motion)
		costs.steps += Time.get_ticks_usec()-start
	func _update_visual_grounding(delta: float) -> void:
		var start := Time.get_ticks_usec()
		super._update_visual_grounding(delta)
		costs.grounding += Time.get_ticks_usec()-start
	func _move_with_car_contacts(delta: float) -> bool:
		var start := Time.get_ticks_usec()
		var value := super._move_with_car_contacts(delta)
		costs.contacts += Time.get_ticks_usec()-start
		return value
	func reference_step(delta: float, target: float, curvature: float) -> void:
		var start := Time.get_ticks_usec()
		super.reference_step(delta,target,curvature)
		costs.movement += Time.get_ticks_usec()-start
		costs.ticks += 1
	func update_slipstream(delta: float) -> void:
		var start := Time.get_ticks_usec()
		super.update_slipstream(delta)
		costs.tow += Time.get_ticks_usec()-start
	func update_zone_state() -> void:
		var start := Time.get_ticks_usec()
		super.update_zone_state()
		costs.zones += Time.get_ticks_usec()-start

func swap_script(node, script) -> void:
	var saved := {}
	for property in node.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			saved[property.name] = node.get(property.name)
	node.set_script(script)
	for property in node.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and saved.has(property.name):
			node.set(property.name,saved[property.name])

## Headless + --fixed-fps 60 measures tick cost, not displayed FPS.
## Render normally with -- --tv --track=michigan --seconds=75 for frame timing.
## --unshared isolates the per-observer projection-cache overhead.
## --park-at=x,y,z,heading reproduces a stationary track-local viewing pose.
## --no-mirrors disables only mirror rendering for a diagnostic comparison.
func _initialize() -> void:
	call_deferred("profile")

func profile() -> void:
	Engine.physics_ticks_per_second = 60
	process_frame.connect(sample_frame)
	var track_id := "texas"
	var seconds := 30.0
	var race_seed := 42
	var traffic_hz := 15
	var speed_hz := -1
	var steering_hz := -1
	var replay_path := ""
	var parked_pose := PackedStringArray()
	var unshared := "--unshared" in OS.get_cmdline_user_args()
	var drive_player := "--drive-player" in OS.get_cmdline_user_args()
	var synchronized_logs := "--synchronized-logs" in OS.get_cmdline_user_args()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--traffic-hz="): traffic_hz = int(argument.trim_prefix("--traffic-hz="))
		if argument.begins_with("--speed-hz="): speed_hz = int(argument.trim_prefix("--speed-hz="))
		if argument.begins_with("--steering-hz="): steering_hz = int(argument.trim_prefix("--steering-hz="))
		if argument.begins_with("--seed="): race_seed = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--replay="): replay_path = argument.trim_prefix("--replay=")
		if argument.begins_with("--park-at="): parked_pose = argument.trim_prefix("--park-at=").split(",")
		if argument.begins_with("--track="): track_id = argument.trim_prefix("--track=")
		if argument.begins_with("--seconds="): seconds = maxf(2.0,float(argument.trim_prefix("--seconds=")))
	root.set_meta("roster_selection",{"track_id":track_id,"file":"res://content/rosters/irl_2001/manifest.json","seed":race_seed,"session_mode":"race","race_laps":20})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	# Diagnostic render comparison only; do not change the game's mirror defaults.
	var no_mirrors := "--no-mirrors" in OS.get_cmdline_user_args()
	if no_mirrors:
		for mirror in main.get_node("DisplayCar/Cockpit").mirror_views:
			mirror.render_target_update_mode = SubViewport.UPDATE_DISABLED
	assert(traffic_hz in [15,30,60])
	for car in main.ai_cars:
		car.get_node("Driver").traffic_update_hz = traffic_hz
		if speed_hz > 0: car.get_node("Driver").speed_plan_hz = speed_hz
		if steering_hz > 0: car.get_node("Driver").steering_plan_hz = steering_hz
	if synchronized_logs:
		for car in main.ai_cars:
			car.get_node("Driver").log_flush_elapsed = 0.0
	if unshared:
		for car in main.ai_cars:
			car.get_node("Driver").racecraft.projection_cache = {}
	if "--tv" in OS.get_cmdline_user_args():
		main.get_node("DisplayCar/Cockpit").deactivate()
		main.get_node("InspectionCamera").make_current()
		main.get_node("InspectionCamera")._activate_tv()
		main.get_node("InspectionCamera")._cycle_tv_subject(1)
	var baseline := "--baseline" in OS.get_cmdline_user_args()
	var instrument := "--instrument" in OS.get_cmdline_user_args()
	if instrument:
		for car in main.ai_cars:
			swap_script(car,TimedCar)
			swap_script(car.get_node("Driver"),TimedDriver)
			swap_script(car.get_node("Driver").racecraft,TimedRacecraft)
	if baseline:
		var old_script = load("res://builds/icr2_driver_before_tow_optimization.gd")
		for car in main.ai_cars:
			var driver = car.get_node("Driver")
			var saved := {}
			for property in driver.get_property_list():
				if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
					saved[property.name] = driver.get(property.name)
			driver.set_script(old_script)
			for property in driver.get_property_list():
				if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and saved.has(property.name):
					driver.set(property.name,saved[property.name])
	var pilot: Node
	if not replay_path.is_empty():
		swap_script(main.player,ReplayPlayer)
		main.player.load_replay(replay_path)
	elif drive_player:
		# Exercise the real player physics, cockpit, mirror and telemetry in motion.
		# Keep human_controlled true for dirty air; replace only keyboard input.
		main.player.set_physics_process(false)
		pilot = preload("res://game/ai/oval_driver.gd").new()
		pilot.name = "Driver"
		main.player.add_child(pilot)
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main.track_session_file.get_base_dir()+"/ai/race_line.json"))
		data.racing_corridor = JSON.parse_string(FileAccess.get_file_as_string(main.track_session_file.get_base_dir()+"/ai/racing_corridor.json"))
		pilot.configure(main.player,data,0)
		pilot.rivals.assign(main.ai_cars)
		pilot.start_formation(pilot.racecraft.coordinates(pilot,main.player).y,main.track_data.pace_speed_kph,main.player_grid_slot/2)
		main.session.green_flag.connect(pilot.release_to_race)
	else:
		# Park the unattended player so it cannot obstruct the starting field.
		main.player.global_transform = main.player.track.global_transform*main.track_data.pit_box_transform()
		main.player.reset_dynamics()
		if not parked_pose.is_empty():
			assert(parked_pose.size() == 4,"--park-at requires track-local x,y,z,heading_degrees")
			main.player.global_position = main.player.track.to_global(Vector3(float(parked_pose[0]),float(parked_pose[1]),float(parked_pose[2])))
			main.player.rotation.y = deg_to_rad(float(parked_pose[3]))
	var green_tick := -1
	var last := Time.get_ticks_usec()
	var samples: Array[float] = []
	var physics: Array[float] = []
	var tow_ticks := 0
	for tick in range(12000):
		await physics_frame
		var now := Time.get_ticks_usec()
		if main.session.status == main.session.Status.RUNNING:
			if green_tick < 0:
				green_tick = tick
				print("RACE START ",track_id," green at ",tick/60.0," baseline=",baseline)
				if instrument:
					for car in main.ai_cars:
						for node in [car,car.get_node("Driver"),car.get_node("Driver").racecraft]:
							for key in node.costs:
								node.costs[key] = 0
			if tick > green_tick+60:
				record_frames = true
				samples.append((now-last)/1000.0)
				physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
			for car in main.ai_cars:
				if car.slipstream_drag_reduction > .01:
					tow_ticks += 1
			if tick-green_tick >= int(seconds*60):
				break
		last = now
	if samples.is_empty():
		push_error("Formation did not reach green")
		quit(1)
		return
	samples.sort()
	physics.sort()
	var item := {"baseline":baseline,"cars":main.ai_cars.size(),"tow_ticks":tow_ticks,"median_tick_ms":samples[samples.size()/2],"p95_tick_ms":samples[int(samples.size()*.95)],"p99_tick_ms":samples[int(samples.size()*.99)],"median_physics_ms":physics[physics.size()/2],"p95_physics_ms":physics[int(physics.size()*.95)]}
	item.track = track_id
	item.unshared = unshared
	item.seconds = seconds
	item.seed = race_seed
	item.traffic_hz = traffic_hz
	item.speed_plan_hz = main.ai_cars[0].get_node("Driver").speed_plan_hz
	item.steering_plan_hz = main.ai_cars[0].get_node("Driver").steering_plan_hz
	item.parked_pose = parked_pose
	item.no_mirrors = no_mirrors
	if not replay_path.is_empty():
		item.replay_file = replay_path.get_file()
		item.replay_max_error_m = main.player.replay_max_error_m
		item.replay_rows = main.player.replay_index
		item.player_speed_kph = main.player.speed_mps*3.6
	item.drive_player = drive_player
	item.synchronized_logs = synchronized_logs
	item.player_telemetry = main.player.telemetry.file != null
	item.ai_telemetry_cars = main.ai_cars.filter(func(car): return car.get_node("Driver").diagnostic != null).size()
	item.minimum_reported_fps = main.get_node("HUD/FPSCounter").minimum_reported_fps
	if drive_player and replay_path.is_empty():
		item.player_laps = pilot.laps
		item.player_speed_kph = main.player.speed_mps*3.6
		item.player_max_line_error_m = pilot.max_line_error_m
	item.rendered = DisplayServer.get_name() != "headless"
	item.window_size = str(DisplayServer.window_get_size())
	item.window_mode = DisplayServer.window_get_mode()
	item.viewport_size = str(root.get_visible_rect().size)
	if not frame_times.is_empty():
		var total_ms := 0.0
		for ms in frame_times: total_ms += ms
		frame_times.sort()
		item.mean_frame_ms = total_ms/frame_times.size()
		item.median_frame_ms = frame_times[frame_times.size()/2]
		item.p95_frame_ms = frame_times[int(frame_times.size()*.95)]
		item.p99_frame_ms = frame_times[int(frame_times.size()*.99)]
		item.max_frame_ms = frame_times[-1]
		item.frames_over_33ms = frame_times.filter(func(ms): return ms > 33.333).size()
		item.frames_over_50ms = frame_times.filter(func(ms): return ms > 50.0).size()
	print("RACE START PROFILE ",JSON.stringify(item))
	if instrument:
		var totals := {}
		for car in main.ai_cars:
			for node in [car,car.get_node("Driver"),car.get_node("Driver").racecraft]:
				for key in node.costs:
					if key != "ticks":
						# Racecraft can run below 60 Hz; normalize all costs to vehicle
						# physics ticks, not to each subsystem's invocation count.
						totals[key] = totals.get(key,0.0)+node.costs[key]/float(maxi(1,car.costs.ticks))/1000.0
		print("RACE DRIVER COSTS ",JSON.stringify(totals))
		item.costs = totals
	var scenario_suffix := ("_parked" if not parked_pose.is_empty() else "")+("_no_mirrors" if no_mirrors else "")
	var file := FileAccess.open("res://builds/%s_start_%s%s%s%s%s.json" % [track_id,"unshared" if unshared else ("before" if baseline else "after"),"_replay" if not replay_path.is_empty() else ("_driving" if drive_player else ""),"_sync_logs" if synchronized_logs else "","_maximized" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED else "",scenario_suffix],FileAccess.WRITE)
	file.store_string(JSON.stringify(item,"  "))
	main.free()
	quit()
