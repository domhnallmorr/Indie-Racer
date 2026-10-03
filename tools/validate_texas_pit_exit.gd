extends SceneTree
## Texas apron clearance, merge conflict/release, and recovery after rear contact.
var failures: Array[String] = []
const DT := 1.0/60.0

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func validate() -> void:
	Engine.physics_ticks_per_second = 480
	Engine.time_scale = 8
	root.set_meta("roster_selection",{"track_id":"texas","file":"res://content/rosters/icr2_test/manifest.json","seed":42,"session_mode":"practice"})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	for body in main.find_children("*","CollisionObject3D",true,false):
		body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var car = main.ai_cars[0]
	var driver = car.get_node("Driver")
	var other = main.ai_cars[1]
	var other_driver = other.get_node("Driver")
	driver.practice_cycle = false
	driver.release_delay = 0
	driver.rivals.clear()
	car.player_state.pit_stall_state = car.player_state.StallState.NONE
	var crossed := false
	var crossing_kph := 0.0
	var crossing_s := 0.0
	for tick in range(6000):
		await physics_frame
		driver._physics_process(DT)
		var at: Vector2 = driver.racecraft.coordinates(driver,car)
		# Corridor inner boundary is 1.5 m outboard of the asphalt's inner edge.
		if not crossed and at.x > 500 and at.x < 1450 and at.y > -10.5:
			crossed = true
			crossing_kph = car.speed_mps*3.6
			crossing_s = at.x
			check(at.x > 1100,"Entered racing surface before the backstraight merge corridor")
			check(crossing_kph > 280,"Insufficient acceleration before entering track")
		if driver.mode == driver.Mode.RACING:
			break
	check(crossed and driver.mode == driver.Mode.RACING,"Departure did not reach racing mode")
	print("TEXAS EXIT crossing_s=",crossing_s," crossing_kph=",crossing_kph)
	# Restart at the yield gate: zero speed must not latch a permanent stop.
	driver.mode = driver.Mode.PIT_EXIT
	driver.merge_committed = false
	for i in range(driver.route.size()):
		if driver.route_distances[i] <= driver.merge_gate_m:
			driver.index = i
	car.global_position = car.track.to_global(driver.route[driver.index])
	car.reset_dynamics()
	other_driver.mode = driver.Mode.RACING
	other.set_meta("pit_ghost",false)
	driver.rivals.assign([other])
	# Put stationary traffic on the final join: the crossing must yield.
	other_driver.index = driver.route_join_index
	other.global_position = car.track.to_global(driver.route[-1])
	other.speed_mps = 0
	check(driver._pit_exit_speed() == 0 and not driver.merge_committed,"Blocked merge must wait on apron")
	other.global_position = car.track.to_global(driver.race[(driver.route_join_index+100)%driver.race.size()])
	other_driver.index = (driver.route_join_index+100)%driver.race.size()
	check(driver._pit_exit_speed() > 0 and driver.merge_committed,"Cleared merge must restart from rest")
	# A fast car can pass through the crossing before the final join is occupied.
	driver.merge_committed = false
	car.speed_mps = 40
	var heading: Vector3 = (driver.race[(driver.route_join_index+1)%driver.race.size()]-driver.route[-1]).normalized()
	var first := -1
	for i in range(driver.index,driver.route.size()):
		if absf((driver.route[i]-driver.route[-1]).dot(heading.cross(Vector3.UP))) < 3.4:
			first = i
			break
	var enter_time: float = (driver.route_distances[first]-driver.route_distances[driver.index])/40.0
	# Place traffic by race arc distance, matching the predictor on this curved
	# backstraight; tangent projection is not an accurate racing-lane position.
	var traffic_s: float = driver.race_distances[driver.route_join_index]+(driver.route[first]-driver.route[-1]).dot(heading)-100*enter_time
	other.global_position = car.track.to_global(driver._sample_path(driver.race,driver.race_distances,fposmod(traffic_s,driver.race_length_m)))
	other.speed_mps = 100
	other_driver.index = 0
	for i in range(driver.race.size()):
		if other.global_position.distance_squared_to(car.track.to_global(driver.race[i])) < other.global_position.distance_squared_to(car.track.to_global(driver.race[other_driver.index])):
			other_driver.index = i
	check(not driver._merge_clear(),"Fast traffic crossing before join must block merge")
	# Exercise real rear contact just after handoff to the racing controller.
	driver.index = driver.route_join_index
	driver.mode = driver.Mode.RACING
	car.global_position = car.track.to_global(driver.route[-1])+Vector3.UP*.025
	car.rotation.y = atan2(-heading.x,-heading.z)
	car.reset_dynamics()
	car.speed_mps = 45
	other.global_transform = car.global_transform
	other.global_position -= heading*5
	other.reset_dynamics()
	other.speed_mps = 90
	other_driver.index = driver.index
	other_driver.rivals.assign([car])
	other_driver._update_car_collisions()
	driver._update_car_collisions()
	var contacts := 0
	for tick in range(600):
		await physics_frame
		driver._physics_process(DT)
		other_driver._physics_process(DT)
		if car.car_contact_this_step or other.car_contact_this_step:
			contacts += 1
	check(contacts > 0,"Rear-impact fixture did not exercise contact")
	check(car.speed_mps > 60,"Car failed to accelerate again after rear contact")
	print("TEXAS EXIT contact_ticks=",contacts," recovered_kph=",car.speed_mps*3.6," failures=",failures)
	main.free()
	quit(0 if failures.is_empty() else 1)
