extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://game/main/main.tscn").instantiate()
	scene.ai_enabled = false
	root.add_child(scene)
	await process_frame
	var player = scene.get_node("DisplayCar")
	player.telemetry.stop()
	assert(player.telemetry.start(player, "res://builds/telemetry_test") == OK)
	for frame in range(10):
		await physics_frame
	player.telemetry.stop()
	var file := FileAccess.open(player.telemetry.path, FileAccess.READ)
	var header := file.get_csv_line()
	for column in ["time_s","drag_n","downforce_n","slipstream_target","slipstream_strength","slipstream_drag_reduction","dirty_air_target","dirty_air_strength","assistance_strength","steering_assistance","stability_assistance","traction_control","anti_lock_brakes","longitudinal_accel_mps2","load_transfer_accel_mps2","load_transfer_n"]:
		assert(column in header,"Missing telemetry column: "+column)
	var rows := 0
	assert("assisted_steering_lock_deg" in header,"Effective input range is recorded")
	for corner in ["fl","fr","rl","rr"]:
		for suffix in ["_load_n","_peak_n","_usage","_demand"]:
			assert(corner+suffix in header,"Missing per-tyre diagnostic")
	assert("front_roll_stiffness_fraction" in header)
	for column in ["automatic_gears","direct_wheel_steering","clutch_engagement","clutch_torque_min_nm","clutch_torque_max_nm","engine_opening","integration_steps"]:
		assert(column in header,"Missing driveline/input diagnostic: "+column)
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		assert(row.size() == header.size())
		assert(float(row[1]) > 0)
		assert(float(row[header.find("integration_steps")]) >= 1)
		assert(is_finite(float(row[header.find("clutch_torque_min_nm")])) and is_finite(float(row[header.find("clutch_torque_max_nm")])))
		assert(float(row[header.find("clutch_torque_min_nm")]) <= float(row[header.find("clutch_torque_max_nm")]))
		assert(float(row[header.find("slipstream_target")]) == 0.0,"Solo parked car has no tow")
		assert(float(row[header.find("slipstream_drag_reduction")]) == 0.0)
		var front_sum := float(row[header.find("fl_load_n")])+float(row[header.find("fr_load_n")])
		var rear_sum := float(row[header.find("rl_load_n")])+float(row[header.find("rr_load_n")])
		assert(absf(front_sum-float(row[header.find("front_load_n")])) < .001)
		assert(absf(rear_sum-float(row[header.find("rear_load_n")])) < .001)
		rows += 1
	assert(rows > 0)
	assert(FileAccess.file_exists(player.telemetry.path.get_basename() + ".cfg"))
	var metadata := ConfigFile.new()
	assert(metadata.load(player.telemetry.path.get_basename()+".cfg") == OK)
	assert(metadata.get_value("run","integration").scheme == "bounded_euler_v1","Log identifies the numerical solver separately from car setup")
	print("TELEMETRY PASSED: ", rows, " rows, ",header.size()," columns, tow fields, metadata and clean stop")
	quit()
