extends SceneTree
## Rendered integration test; injected timestamps make hitch counts deterministic.
func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Frame diagnostics validation requires a renderer")
		quit(1)
		return
	var main = load("res://game/main/main.tscn").instantiate()
	main.ai_enabled = false
	root.add_child(main)
	var counter = main.get_node("HUD/FPSCounter")
	counter.set_process(false)
	await RenderingServer.frame_post_draw
	var directory := "res://builds/frame_diagnostics_test_"+str(Time.get_ticks_usec())
	counter.diagnostics_directory = directory
	var now_usec := 1000000
	counter._record_frame(now_usec)
	for frame in range(140):
		now_usec += 40000
		counter._record_frame(now_usec)
	now_usec += 80000
	counter._record_frame(now_usec)
	now_usec += 16000
	counter._record_frame(now_usec)
	assert(counter.measured_frames == 142)
	assert(counter.frames_over_33ms == 141 and counter.frames_over_50ms == 1)
	assert(counter.hitches.size() == 128)
	assert(not DirAccess.dir_exists_absolute(directory), "No disk writes while measuring")
	# Exclude time spent outside the running session, including resume intervals.
	main.session.status = main.session.Status.FINISHED
	counter._record_frame(now_usec+10000000)
	main.session.status = main.session.Status.RUNNING
	counter._record_frame(now_usec+20000000)
	assert(counter.measured_frames == 142)
	main.free()
	await process_frame
	var files := DirAccess.get_files_at(directory)
	assert(files.size() == 1, "Normal shutdown saves exactly one report")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+"/"+files[0]))
	assert(report.measured_frames == 142 and report.worst_frame_ms == 80.0)
	assert(report.frames_over_33ms == 141 and report.frames_over_50ms == 1)
	assert(report.recent_hitches.size() == 128)
	assert(is_equal_approx(report.recent_hitches[0].elapsed_s,.56))
	assert(is_equal_approx(report.recent_hitches[-1].elapsed_s,5.68))
	assert("DriverEye" in report.recent_hitches[-1].camera)
	assert(report.has("window_size") and report.has("seed"))
	print("FRAME DIAGNOSTICS PASSED: bounded hitch history, exact totals, inactive-time exclusion, cockpit context and shutdown-only writes.")
	quit()
