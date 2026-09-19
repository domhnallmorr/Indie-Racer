extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://game/main/main.tscn").instantiate()
	scene.ai_enabled = false
	root.add_child(scene)
	await process_frame
	var player = scene.get_node("DisplayCar")
	assert(player.telemetry.start(player, "res://builds/telemetry_test") == OK)
	for frame in range(10):
		await physics_frame
	player.telemetry.stop()
	var file := FileAccess.open(player.telemetry.path, FileAccess.READ)
	var header := file.get_csv_line()
	assert(header.size() == 45)
	var rows := 0
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		assert(row.size() == header.size())
		assert(float(row[1]) > 0)
		rows += 1
	assert(rows > 0)
	assert(FileAccess.file_exists(player.telemetry.path.get_basename() + ".cfg"))
	print("TELEMETRY PASSED: ", rows, " rows, 45 columns, metadata and clean stop")
	quit()
