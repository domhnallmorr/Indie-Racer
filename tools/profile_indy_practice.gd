extends Node
## Sequential full-field practice fixture. Render without --fixed-fps.
const Instrument = preload("res://tools/profile_texas_start.gd")
var main: Node
var pilot: Node

func _ready() -> void:
	call_deferred("profile")

func percentile(values: Array[float], fraction: float) -> float:
	values.sort()
	return values[mini(values.size()-1,int(values.size()*fraction))]

func swap_script(node: Object, script: Script) -> void:
	var saved := {}
	for property in node.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: saved[property.name] = node.get(property.name)
	node.set_script(script)
	for property in node.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and saved.has(property.name): node.set(property.name,saved[property.name])

func profile() -> void:
	var hz := 120
	var seconds := 60.0
	var warmup := 10.0
	var output := "user://telemetry/indy_practice_profile.json"
	var args := OS.get_cmdline_user_args()
	for argument in args:
		if argument.begins_with("--hz="): hz = int(argument.trim_prefix("--hz="))
		if argument.begins_with("--seconds="): seconds = float(argument.trim_prefix("--seconds="))
		if argument.begins_with("--warmup="): warmup = float(argument.trim_prefix("--warmup="))
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	assert(hz in [60,120] and seconds >= 2 and warmup >= 0)
	Engine.physics_ticks_per_second = hz
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	get_tree().root.set_meta("roster_selection",{"track_id":"indianapolis","file":"res://content/rosters/irl_2001/manifest.json","seed":1326195860,"session_mode":"practice","incident_mode":"off"})
	main = load("res://game/main/main.tscn").instantiate()
	get_tree().root.add_child(main)
	assert(main.ai_cars.size() == 20)
	if "--original-road" in args:
		var surface = main.player.track.get_node("RacingSurface")
		var shape = surface.get_child(0).get_child(0)
		shape.shape = surface.mesh.create_trimesh_shape()
	var fixture = load("res://tools/validate_racecraft.gd").new()
	for i in range(main.ai_cars.size()):
		var car = main.ai_cars[i]
		var driver = car.get_node("Driver")
		driver.practice_cycle = false
		driver.race_plan.failure_progress = INF
		fixture.place(car,200+i*150,0,85)
	if "--moving-player" in args:
		main.player.set_physics_process(false)
		main.player_state.pit_stall_state = main.player_state.StallState.NONE
		pilot = load("res://game/ai/oval_driver.gd").new()
		pilot.name = "Driver"
		main.player.add_child(pilot)
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/indianapolis/ai/race_line.json"))
		data.racing_corridor = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/indianapolis/ai/racing_corridor.json"))
		pilot.configure(main.player,data,0)
		pilot.rivals.assign(main.ai_cars)
		fixture.place(main.player,100,0,85)
	fixture.free()
	if "--instrument" in args:
		for car in main.ai_cars:
			swap_script(car,Instrument.TimedCar)
			swap_script(car.get_node("Driver"),Instrument.TimedDriver)
			swap_script(car.get_node("Driver").racecraft,Instrument.TimedRacecraft)
	var warm_tick := Engine.get_physics_frames()
	while Engine.get_physics_frames()-warm_tick < roundi(warmup*hz): await get_tree().physics_frame
	if "--instrument" in args:
		for car in main.ai_cars:
			for node in [car,car.get_node("Driver"),car.get_node("Driver").racecraft]:
				for key in node.costs: node.costs[key] = 0
	var frames: Array[float] = []
	var physics: Array[float] = []
	var ticks := {}
	var last_tick := Engine.get_physics_frames()
	var start_tick := last_tick
	var last := Time.get_ticks_usec()
	var start := last
	var over33 := 0
	var over50 := 0
	print("INDY PROFILE START hz=",hz," seconds=",seconds)
	while Engine.get_physics_frames()-start_tick < roundi(seconds*hz):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now-last)/1000.0
		frames.append(ms)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		var tick := Engine.get_physics_frames()
		ticks[tick-last_tick] = ticks.get(tick-last_tick,0)+1
		last_tick = tick
		last = now
		if ms > 33.333: over33 += 1
		if ms > 50: over50 += 1
	var wall_seconds := (last-start)/1000000.0
	var poses := []
	for car in main.ai_cars:
		poses.append({"name":str(car.name),"position":str(car.global_position),"speed_mps":car.speed_mps,"grounded":car.is_on_floor(),"laps":car.get_node("Driver").laps})
	var result := {"hz":hz,"seed":1326195860,"cars":20,"simulation_seconds":(last_tick-start_tick)/float(hz),"wall_seconds":wall_seconds,"rendered":DisplayServer.get_name() != "headless","moving_player":"--moving-player" in args,"player_speed_kph":main.player.speed_mps*3.6,"player_laps":pilot.laps if pilot != null else 0,"original_road":"--original-road" in args,"instrumented":"--instrument" in args,"window_size":str(DisplayServer.window_get_size()),"mean_frame_ms":wall_seconds*1000/frames.size(),"mean_fps":frames.size()/wall_seconds,"p95_frame_ms":percentile(frames,.95),"p99_frame_ms":percentile(frames,.99),"worst_frame_ms":frames[-1],"frames_over_33ms":over33,"frames_over_50ms":over50,"median_physics_monitor_ms":percentile(physics,.5),"ticks_per_frame":ticks,"poses":poses,"note":"Deployed, spaced full-field practice fixture, not a replay of human laps. Headless timing measures throughput, not FPS. Monitors are periodic snapshots."}
	if "--instrument" in args:
		var costs := {}
		for car in main.ai_cars:
			for node in [car,car.get_node("Driver"),car.get_node("Driver").racecraft]:
				for key in node.costs:
					if key != "ticks": costs[key] = costs.get(key,0.0)+node.costs[key]/float(maxi(1,car.costs.ticks))/1000
		result.field_cost_ms_per_tick = costs
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null:
		push_error("Cannot save Indy profile to "+output)
		main.free()
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print("INDY PROFILE RESULT ",JSON.stringify(result))
	print("Indy profile saved: ",ProjectSettings.globalize_path(output))
	main.free()
	get_tree().quit()



