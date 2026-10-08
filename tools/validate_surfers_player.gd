extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func validate() -> void:
	root.set_meta("roster_selection",{"track_id":"surfers_paradise","session_mode":"private_testing","ai_telemetry":false})
	var menu = load("res://game/main/menu.tscn").instantiate()
	root.add_child(menu)
	check(menu.selected_track_name == "Surfers Paradise — CART 1995","Track is selectable in the weekend menu")
	menu.free()
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	for i in range(5): await physics_frame
	check(main.player.physics_ready and main.player.driving_enabled,"Player physics ready")
	check(main.ai_cars.is_empty() and main.pace_car == null,"Private session is solo")
	check(main.player_state.is_in_pit_lane and main.player_state.is_in_pit_speed_zone,"Spawn in pit lane/limiter")
	check(main.player.can_adjust_aero(),"Pit setup available")
	check(main.player.sim.p.body_package == "road","Street-course baseline uses road aero")
	var excludes: Array[RID] = [main.player.get_rid()]
	var track: Node3D = main.get_node("MileOval")
	for box in main.track_data.pit_boxes:
		var at := track.to_global(Vector3(box.position[0],0,box.position[2]))
		var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*2,at-Vector3.UP,1,excludes)
		var hit := root.world_3d.direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and absf(hit.position.y)<.02,"Paved stall "+box.id)
	main.player_state.request_departure()
	check(main.player_state.pit_stall_state != main.player_state.StallState.STOPPED,"Player can leave pits")
	var event := InputEventKey.new()
	event.keycode = KEY_R
	event.pressed = true
	main._unhandled_input(event)
	check(main.player_state.pit_stall_state == main.player_state.StallState.STOPPED,"Reset returns to assigned box")
	print("SURFERS PLAYER ","PASS" if failures.is_empty() else failures)
	main.free()
	quit(0 if failures.is_empty() else 1)
