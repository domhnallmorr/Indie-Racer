extends SceneTree
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	return event

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	root.set_meta("roster_selection",{"file":"res://content/rosters/icr2_test/manifest.json","seed":42,"session_mode":"race"})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	var camera = main.get_node("InspectionCamera")
	var entries: Array[Dictionary] = main.lap_timing.entries
	for entry in entries:
		entry.laps = 0
		entry.expected = 1
		entry.armed = true
	entries[0].previous = Vector3(100,0,100)
	entries[1].previous = Vector3(280,0,15)
	entries[2].previous = Vector3(100,0,100)
	entries[2].laps = 1
	var position_order: Array = main.lap_timing.track_order()
	check(position_order[0] == entries[2],"Completed laps take priority in physical track order")
	check(position_order[1] == entries[1],"Distance along the current track sector resolves position")
	camera._unhandled_input(key_event(KEY_T))
	check(camera.current and camera.tv_mode,"T activates the TV trackside camera")
	check(camera.followed_subject() == main.player,"TV mode initially follows the player")
	var ordered: Array = main.lap_timing.track_order()
	var player_index: int = ordered.find_custom(func(entry): return entry.car == main.player)
	camera._unhandled_input(key_event(KEY_KP_ADD))
	var expected: Node3D = ordered[posmod(player_index+1,ordered.size())].car
	check(camera.followed_subject() == expected,"Numpad + selects the next car in track order")
	camera._unhandled_input(key_event(KEY_KP_SUBTRACT))
	check(camera.followed_subject() == main.player,"Numpad - selects the previous car in track order")
	var last_car: Node3D = ordered[-1].car
	camera.followed_ai = main.ai_cars.find(last_car)
	camera._unhandled_input(key_event(KEY_KP_ADD))
	check(camera.followed_subject() == ordered[0].car,"Ordered camera cycling wraps after the final car")
	camera.followed_ai = -1
	var first_camera: int = camera.tv_camera_index
	main.player.global_position = main.get_node("MileOval").to_global(Vector3(-330,0,0))
	camera._update_tv_camera(true)
	check(camera.tv_camera_index != first_camera,"TV camera hands off around the circuit")
	check(camera.followed_position() == player_index+1,"HUD position uses physical track order")
	for failure in failures:
		push_error(failure)
	print("TV CAMERA CHECK PASSED: activation, physical order, cycling/wrap and trackside handoff." if failures.is_empty() else "TV CAMERA CHECK FAILED")
	quit(0 if failures.is_empty() else 1)
