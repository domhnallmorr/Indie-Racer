extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func validate() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	var session = main.session
	session.set_process(false)
	check(session.clock_text() == "60:00", "Initial practice duration")
	check(session.status == session.Status.RUNNING, "Practice started")
	check(main.player_state.is_in_pit_lane, "Spawn has pit-lane state")
	check(main.player_state.assigned_pit_box_id == "player_pit_01", "Assigned pit box")
	check(main.get_node("MileOval").to_local(main.player.global_position).distance_to(Vector3(-81.04,.025,92.75)) < .001, "Spawn coordinates")
	check((-main.player.basis.z).dot(Vector3.RIGHT) > .999, "Spawn facing race direction")
	var data = main.track_data
	check(data.contains_pit_lane(Vector3(0,.025,101)), "Pit fast lane included")
	check(data.contains_pit_lane(data.pit_path[300]), "Extended pit exit included")
	check(not data.contains_pit_lane(Vector3(0,.025,125)), "Front straight excluded")
	check(not data.contains_pit_lane(Vector3(0,.025,0)), "Infield excluded")
	check(not data.contains_pit_lane(Vector3(-81.04,10,92.75)), "Height bounds")
	var spawn: Transform3D = main.player.transform
	main.player.global_position = main.get_node("MileOval").to_global(Vector3(0,.025,125))
	main._physics_process(0.0)
	check(not main.player_state.is_in_pit_lane, "State updates on exit")
	main.player.transform = spawn
	main._physics_process(0.0)
	check(main.player_state.is_in_pit_lane, "State updates on return")
	session.advance(1.25)
	check(session.clock_text() == "59:59", "Clock ticks")
	session.advance(3600)
	check(session.remaining_seconds == 0 and session.status == session.Status.FINISHED, "Clock finishes at zero")
	session.advance(60)
	check(session.remaining_seconds == 0, "No negative time")
	session.start_practice()
	check(session.clock_text() == "60:00", "Practice restart")
	await physics_frame
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(main.player.global_position + Vector3.UP, main.player.global_position - Vector3.UP)
	query.exclude = [main.player.get_rid()]
	var hit = main.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty(), "Pit-box ground collision")
	if not hit.is_empty():
		check(absf(main.get_node("MileOval").to_local(hit.position).y) < .02, "Pit-box surface height")
	var cockpit = main.get_node("DisplayCar/Cockpit")
	cockpit._process(0.0)
	check(cockpit.rear_cameras[0].global_position.distance_to(cockpit.global_transform * cockpit.rear_local_poses[0].origin) < .001, "Mirror follows pit spawn")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PRACTICE CHECK PASSED: clock, expiry, spawn, heading, pit regions, state transitions, ground and mirrors.")
	quit(0 if failures.is_empty() else 1)
