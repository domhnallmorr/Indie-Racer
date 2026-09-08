extends SceneTree
func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	var car = main.ai_cars[0]
	var driver = car.get_node("Driver")
	var player = main.player
	player.global_position = car.global_position + car.global_basis * Vector3(8,0,-10)
	assert(not driver._departure_clear(), "Wait for occupied pit travel lane")
	player.global_position = Vector3(0,0,0)
	assert(driver._departure_clear(), "Release when lane clear")
	car.position = Vector3(80,0,-112)
	player.position = Vector3(130,0,-125)
	assert(not driver._merge_clear(), "Yield to approaching backstraight traffic")
	player.position = Vector3(-60,0,-125)
	assert(driver._merge_clear(), "Merge when traffic has passed")
	car.rotation.y = -PI/2
	player.global_position = car.global_position + car.global_basis * Vector3(0,0,-8)
	assert(driver._traffic_speed(30) < 1, "Slow behind close car")
	for key in [KEY_6,KEY_7,KEY_5]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		main.get_node("DisplayCar/Cockpit")._unhandled_input(event)
		main.get_node("InspectionCamera")._unhandled_input(event)
		assert(main.get_node("DisplayCar/Cockpit").camera.current == (key == KEY_5))
	print("AI TRAFFIC CHECK PASSED: pit departure hold, merge gap, following, AI cameras.")
	quit()
