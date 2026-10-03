extends SceneTree
## Michigan qualifying: restoring contacts inside a rival must not bury a car.
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("validate")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
func validate() -> void:
	root.set_meta("roster_selection",{"track_id":"michigan","file":"res://content/rosters/icr2_test/manifest.json","seed":42,"ai_telemetry":false})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.player.telemetry.stop()
	for body in main.find_children("*","CollisionObject3D",true,false):
		body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var car = main.ai_cars[0]
	var other = main.ai_cars[1]
	var driver = car.get_node("Driver")
	var other_driver = other.get_node("Driver")
	car.reset_dynamics()
	other.reset_dynamics()
	car.rotation = Vector3(0,PI/2,0)
	other.rotation = car.rotation
	car.global_position = Vector3(-29,1.1,-332.7)
	other.global_position = Vector3(-29,1.112,-333.4)
	car.player_state.set_in_pit_lane(false)
	other.player_state.set_in_pit_lane(false)
	driver.mode = driver.Mode.PIT_EXIT
	other_driver.mode = other_driver.Mode.RACING
	other_driver.car_ghost = false
	other.set_meta("pit_ghost",false)
	driver._update_car_collisions()
	await physics_frame
	await physics_frame
	check(driver._overlaps_rival(),"Fixture must overlap the racing car at the Michigan pit merge")
	driver.mode = driver.Mode.RACING
	driver._update_car_collisions()
	other_driver._update_car_collisions()
	check(driver.car_ghost and car.get_meta("pit_ghost"),"Overlapping merge must defer physical car contacts")
	check(other in car.get_collision_exceptions() and car in other.get_collision_exceptions(),"Both update orders must retain reciprocal collision exceptions")
	car.speed_mps = 85
	car.velocity = Vector3(-85,0,0)
	for tick in range(30):
		car.reference_step(1.0/60.0,85,0)
		driver._update_car_collisions()
		other_driver._update_car_collisions()
		check(car.global_position.y > .5,"Merged car must remain above the road skin")
		await physics_frame
	check(not driver.car_ghost and not car.get_meta("pit_ghost"),"Contacts must resume once the chassis clears the rival")
	check(not other in car.get_collision_exceptions() and not car in other.get_collision_exceptions(),"Normal racing contacts must be restored reciprocally")
	check(car.speed_mps > 80,"Merged car must retain forward motion")
	# A cached pair must follow either driver's transitions in either order,
	# including unchanged states and both cars entering/leaving ghost mode.
	car.player_state.set_in_pit_lane(false)
	other.player_state.set_in_pit_lane(false)
	for reverse_order in [false,true]:
		for flags in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1),Vector2i(0,0),Vector2i(0,0)]:
			driver.mode = driver.Mode.PIT_EXIT if flags.x else driver.Mode.RACING
			other_driver.mode = other_driver.Mode.PIT_EXIT if flags.y else other_driver.Mode.RACING
			for observer in ([other_driver,driver] if reverse_order else [driver,other_driver]):
				observer._update_car_collisions()
			var excluded: bool = flags.x != 0 or flags.y != 0
			check((other in car.get_collision_exceptions()) == excluded and (car in other.get_collision_exceptions()) == excluded,"Cached collision pair must track both ghost flags and update orders")
	print("MICHIGAN MERGE at=",car.global_position," speed=",car.speed_mps," ghost=",driver.car_ghost)
	main.free()
	for failure in failures:
		push_error(failure)
	print("PIT MERGE CONTACTS PASSED" if failures.is_empty() else "PIT MERGE CONTACTS FAILED")
	quit(0 if failures.is_empty() else 1)
