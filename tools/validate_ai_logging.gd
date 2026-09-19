extends SceneTree
const PATH := "res://builds/ai_logging_test.csv"

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	assert(not main.ai_telemetry_enabled)
	for car in main.ai_cars:
		assert(car.get_node("Driver").diagnostic == null, "Default field must not open telemetry files")
	assert(main.has_node("HUD/FPSCounter"))
	assert(not main.get_node("HUD/RaceUI/Shell/Layout/Content/Pages/RosterPanel").record_ai.button_pressed)
	assert(not FileAccess.file_exists(PATH), "Refuse to overwrite existing test fixture")
	DirAccess.make_dir_recursive_absolute("res://builds")
	var driver = preload("res://game/ai/oval_driver.gd").new()
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
	print("AI LOGGING PASSED: default off, buffered writes and shutdown flush; FPS counter present.")
	quit()
