extends SceneTree
## Run rendered, without --fixed-fps, in a maximised window. Diagnostic only.
## Full scene vs live physics with 3D rendering disabled vs a frozen full scene.

func _initialize() -> void:
	call_deferred("profile")

func percentile(values: Array[float], fraction: float) -> float:
	values.sort()
	return values[mini(values.size()-1,int(values.size()*fraction))]

func profile() -> void:
	var case_name := "live_full"
	var seconds := 60.0
	var freeze_at := 30.0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--case="): case_name = argument.trim_prefix("--case=")
		if argument.begins_with("--seconds="): seconds = float(argument.trim_prefix("--seconds="))
		if argument.begins_with("--freeze-at="): freeze_at = float(argument.trim_prefix("--freeze-at="))
	assert(case_name in ["live_full","live_minimal","live_no_shadows","frozen_full"])
	assert(seconds >= 5 and freeze_at >= 2)
	assert(DisplayServer.get_name() != "headless","Isolation requires an actual renderer")
	Engine.physics_ticks_per_second = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	root.set_meta("roster_selection",{"track_id":"mile_oval","file":"res://content/rosters/irl_2001/manifest.json","seed":1181179623,"session_mode":"race","race_laps":20})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	assert(main.player.track != null and main.ai_cars.size() == 20)
	main.player.global_position = main.player.track.to_global(Vector3(141.00145,-0.09958,-89.36896))
	main.player.rotation.y = deg_to_rad(75.69587)
	main.player.reset_dynamics()
	var green_tick := -1
	for tick in range(12000):
		await physics_frame
		if main.session.status == main.session.Status.RUNNING:
			green_tick = Engine.get_physics_frames()
			break
	assert(green_tick >= 0,"Formation did not reach green")
	var frozen := case_name == "frozen_full"
	var start_after := freeze_at if frozen else 1.0
	while Engine.get_physics_frames()-green_tick < roundi(start_after*60):
		await physics_frame
	var nodes: Array[Node] = [main]
	nodes.append_array(main.find_children("*","",true,false))
	var frozen_poses := {}
	var frozen_elapsed := {}
	if frozen:
		for car in main.ai_cars:
			frozen_poses[car.name] = car.global_transform
			frozen_elapsed[car.name] = car.get_node("Driver").elapsed
		# Preserve cameras, meshes, lights, shadows and viewport update modes.
		# Disable callbacks individually, without changing visibility or bodies.
		for node in nodes:
			node.set_process(false)
			node.set_physics_process(false)
		PhysicsServer3D.set_active(false)
	elif case_name == "live_minimal":
		# The same world and collision shapes keep simulating. Only 3D drawing
		# is removed; HUD and normal telemetry remain active.
		root.disable_3d = true
		for node in nodes:
			if node is SubViewport: node.disable_3d = true
	elif case_name == "live_no_shadows":
		main.get_node("Sun").shadow_enabled = false
	# Allow pipeline changes/periodic monitors to settle before measuring.
	var warm_end := Time.get_ticks_usec()+2000000
	while Time.get_ticks_usec() < warm_end: await process_frame
	var elapsed_start: float = main.ai_cars[0].get_node("Driver").elapsed
	var frames: Array[float] = []
	var physics_ms: Array[float] = []
	var draw_calls: Array[float] = []
	var tick_histogram := {}
	var over33 := 0
	var over50 := 0
	var last := Time.get_ticks_usec()
	var start := last
	var sample_start_unix_s := Time.get_unix_time_from_system()
	var last_physics := Engine.get_physics_frames()
	print("ISOLATION SAMPLE ",case_name," seconds=",seconds," freeze_at=",freeze_at)
	while Time.get_ticks_usec()-start < seconds*1000000:
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now-last)/1000.0
		frames.append(ms)
		physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var tick := Engine.get_physics_frames()
		var count := tick-last_physics
		tick_histogram[count] = tick_histogram.get(count,0)+1
		last_physics = tick
		last = now
		if ms > 33.333: over33 += 1
		if ms > 50: over50 += 1
	var unchanged := true
	if frozen:
		for car in main.ai_cars:
			unchanged = unchanged and car.global_transform == frozen_poses[car.name] and car.get_node("Driver").elapsed == frozen_elapsed[car.name]
	var duration := (last-start)/1000000.0
	var result := {"case":case_name,"seconds":duration,"sample_start_unix_s":sample_start_unix_s,"frames":frames.size(),
		"mean_frame_ms":duration*1000/frames.size(),"mean_fps":frames.size()/duration,
		"p95_frame_ms":percentile(frames,.95),"p99_frame_ms":percentile(frames,.99),
		"worst_frame_ms":frames[-1],"frames_over_33ms":over33,"frames_over_50ms":over50,
		"median_physics_monitor_ms":percentile(physics_ms,.5),"p95_physics_monitor_ms":percentile(physics_ms,.95),
		"median_draw_calls":percentile(draw_calls,.5),"max_draw_calls":draw_calls[-1],
		"physics_ticks_per_render":tick_histogram,"frozen_poses_unchanged":unchanged if frozen else null,
		"driver_elapsed_advance_s":main.ai_cars[0].get_node("Driver").elapsed-elapsed_start,
		"freeze_at_s":freeze_at if frozen else null,"cars":main.ai_cars.size(),"seed":1181179623,
		"speed_plan_hz":main.ai_cars[0].get_node("Driver").speed_plan_hz,
		"steering_plan_hz":main.ai_cars[0].get_node("Driver").steering_plan_hz,
		"window_size":str(DisplayServer.window_get_size()),"vsync":DisplayServer.window_get_vsync_mode(),
		"note":"Physics/draw monitors are periodic snapshots, not isolated CPU/GPU timers. Frozen stops callbacks and the 3D physics server, retaining all visible geometry and viewport rendering."}
	print("ISOLATION RESULT ",JSON.stringify(result))
	var suffix := "_"+str(int(freeze_at)) if frozen else ""
	var file := FileAccess.open("res://builds/mile_isolation_"+case_name+suffix+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	assert(not frozen or unchanged,"Frozen simulation changed during sampling")
	main.free()
	quit()
