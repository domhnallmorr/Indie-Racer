extends SceneTree
const PATH := "res://builds/ai_logging_test.csv"

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	root.set_meta("roster_selection",{"track_id":"texas","file":"res://content/rosters/irl_2001/manifest.json","seed":42,"session_mode":"race"})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	assert(main.ai_telemetry_enabled)
	for car in main.ai_cars:
		assert(car.get_node("Driver").diagnostic != null, "Default field must open AI telemetry files")
	var phases := {}
	for car in main.ai_cars:
		phases[car.get_node("Driver").log_flush_elapsed] = true
	assert(phases.size() > main.ai_cars.size()/2, "Texas log flushes must be spread across the second")
	assert(main.has_node("HUD/FPSCounter"))
	assert(main.get_node("HUD/RaceUI/Shell/Layout/Content/Pages/RosterPanel").record_ai.button_pressed)
	assert(not FileAccess.file_exists(PATH), "Refuse to overwrite existing test fixture")
	DirAccess.make_dir_recursive_absolute("res://builds")
	for script in [preload("res://game/ai/oval_driver.gd"),preload("res://game/ai/icr2_driver.gd")]:
		validate_buffer(script)
	# Run actual Texas logging, then verify the final partial batch on shutdown.
	main.session.show_green()
	for tick in range(37):
		await physics_frame
	var paths: Array[String] = []
	var expected_rows: Array[int] = []
	for car in main.ai_cars:
		var driver = car.get_node("Driver")
		paths.append(driver.diagnostic.get_path())
		# Flush the OS buffer only, leaving the application batch pending.
		driver.diagnostic.flush()
		expected_rows.append(FileAccess.get_file_as_string(paths[-1]).strip_edges().split("\n").size()+driver.pending_log_rows.size())
	main.free()
	for i in range(paths.size()):
		var lines := FileAccess.get_file_as_string(paths[i]).strip_edges().split("\n")
		assert(lines.size() == expected_rows[i] and lines.size() > 1)
		for line in lines:
			assert(line.split(",").size() == 22, "Texas telemetry schema must stay intact")
	print("AI LOGGING PASSED: Texas staggered flushes, both controller buffers, live rows and shutdown preservation; FPS counter present.")
	quit()

func validate_buffer(script: Script) -> void:
	var driver = script.new()
	root.add_child(driver)
	driver.set_physics_process(false)
	driver.diagnostic = FileAccess.open(PATH,FileAccess.WRITE)
	assert(driver.diagnostic != null)
	driver.pending_log_rows.append("first,row")
	assert(FileAccess.get_file_as_string(PATH).is_empty(), "Rows remain buffered before flush")
	driver._flush_diagnostic()
	assert(FileAccess.get_file_as_string(PATH) == "first,row\n", "Flush writes buffered rows")
	assert(driver.pending_log_rows.is_empty(), "Flushed rows are removed")
	driver.pending_log_rows.append("final,row")
	driver.free()
	assert(FileAccess.get_file_as_string(PATH) == "first,row\nfinal,row\n", "Normal shutdown preserves final partial batch")
	DirAccess.remove_absolute(PATH)
