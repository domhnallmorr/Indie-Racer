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
	driver.mode = driver.Mode.PIT_EXIT
	driver.rivals.assign([player])
	for i in range(driver.route.size()):
		if driver.route_distances[i] <= driver.merge_gate_m:
			driver.index = i
	car.global_position = car.track.to_global(driver.route[driver.index])
	var gate_position: Vector3 = car.track.to_local(car.global_position)
	car.speed_mps = 60
	player.speed_mps = 60
	player.global_position = car.track.to_global(Vector3(gate_position.x+50,0,-125))
	assert(driver._merge_clear(), "Same-speed rear car with 50 m gap must not cause yielding")
	assert(driver._pit_exit_speed() > 60 and driver.merge_committed, "Safe rear gap must retain acceleration through gate")
	driver.merge_committed = false
	player.speed_mps = 80
	player.global_position = car.track.to_global(Vector3(gate_position.x+40,0,-125))
	assert(not driver._merge_clear(), "Yield when faster traffic overlaps during the blend")
	assert(driver._pit_exit_speed() == 0 and not driver.merge_committed, "Real conflict still holds on apron")
	player.global_position = car.track.to_global(Vector3(gate_position.x-100,0,-125))
	assert(driver._pit_exit_speed() > 60 and driver.merge_committed, "Passed traffic releases merge")
	player.global_position = car.track.to_global(Vector3(gate_position.x+40,0,-125))
	assert(driver._pit_exit_speed() > 60, "Late rear traffic cannot stop a committed merge")
	var queued = main.ai_cars[1]
	queued.global_position = player.global_position
	queued.speed_mps = player.speed_mps
	driver.rivals.assign([queued])
	queued.get_node("Driver").mode = driver.Mode.PIT_EXIT
	assert(driver._merge_clear(), "Pit-exit queue must not mutually block merge")
	queued.get_node("Driver").mode = driver.Mode.RACING
	assert(not driver._merge_clear(), "Racing traffic on collision course must block merge")
	driver.rivals.assign([player])
	assert(driver.route[-1].distance_to(driver.race[driver.route_join_index]) < .001, "Exit must meet actual race line")
	var join_direction: Vector3 = (driver.route[-1]-driver.route[-2]).normalized()
	var race_direction: Vector3 = (driver.race[driver.route_join_index+1]-driver.race[driver.route_join_index]).normalized()
	assert(join_direction.dot(race_direction) > .999, "Exit must join race direction smoothly")
	player.speed_mps = 0
	car.rotation.y = -PI/2
	player.global_position = car.global_position + car.global_basis * Vector3(0,0,-8)
	assert(driver._traffic_speed(30) < 1, "Slow behind close car")
	player.speed_mps = 40
	player.global_position = car.global_position + car.global_basis * Vector3(0,0,-30)
	var following_target: float = driver._traffic_speed(70)
	assert(following_target > 20 and following_target < 40, "Slower moving leader should reduce pace without commanding a stop")
	for key in [KEY_6,KEY_7,KEY_5]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		main.get_node("DisplayCar/Cockpit")._unhandled_input(event)
		main.get_node("InspectionCamera")._unhandled_input(event)
		assert(main.get_node("DisplayCar/Cockpit").camera.current == (key == KEY_5))
	print("AI TRAFFIC CHECK PASSED: pit departure, apron yield, committed merge, closing traffic, tangent join, following, cameras.")
	quit()
