extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
func run() -> void:
	Engine.physics_ticks_per_second = 120
	root.set_meta("roster_selection",{"file":"res://content/rosters/icr2_full/manifest.json","seed":42,"session_mode":"race"})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	# Crossing the green zone must not release the field while the pace car
	# is still on track. Also exercise a human pole sitter after qualifying.
	main.formation_leader = main.player
	main.player.global_position = main.get_node("MileOval").to_global(main.track_data.green_point+Vector3(2,0,0))
	main._physics_process(0.0)
	check(main.session.status == main.session.Status.FORMATION,"Human leader cannot get green before pace car clears")
	main.pace_car.clear_of_track = true
	main._physics_process(0.0)
	check(main.session.status == main.session.Status.RUNNING,"Human leader receives green once pace car clears")
	if "--start-only" in OS.get_cmdline_user_args():
		print("PACE START INTERLOCK failures=",failures)
		main.free()
		quit(0 if failures.is_empty() else 1)
		return
	# Reload to restore driver launch state after the synthetic green.
	main.free()
	main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.player.global_transform = main.get_node("MileOval").global_transform*main.track_data.pit_box_transform()
	main.player.reset_dynamics()
	var pace = main.pace_car
	check(main.track_data.pit_boxes.size() == 26,"26 assignable racing boxes")
	check(main.track_data.pace_car_box.origin.x+2.5 < main.track_data.speed_exit_x,"Pace bay before limiter exit")
	for box in main.track_data.pit_boxes:
		var p := Vector3(box.position[0],box.position[1],box.position[2])
		check(main.track_data.contains_pit_lane(p),"Race box on pit surface")
		check(p.distance_to(main.track_data.pace_car_box.origin)>8.0,"Pace bay separate from race boxes")
	var green := false
	var pulled_away := false
	var max_speed := 0.0
	var last_phase := -1
	var min_gap := INF
	for tick in range(120*100):
		await physics_frame
		max_speed = maxf(max_speed,pace.speed_mps*3.6)
		if pace.phase != last_phase:
			print("PACE phase=",pace.phase," t=",tick/120.0," position=",pace.global_position," speed=",pace.speed_mps*3.6)
			last_phase = pace.phase
		if pace.phase == pace.Phase.LEADING:
			min_gap = minf(min_gap,pace.global_position.distance_to(main.formation_leader.global_position))
		if pace.phase == pace.Phase.PULLING_AWAY:
			pulled_away = true
		if main.session.status == main.session.Status.RUNNING and not green:
			green = true
			check(pace.clear_of_track,"Green only after pace car clears track")
			print("GREEN t=",tick/120.0," pace=",pace.global_position," leader=",main.formation_leader.global_position)
		if main.track_data.contains_speed_limit_zone(main.get_node("MileOval").to_local(pace.global_position)):
			check(pace.speed_mps*3.6 <= 80.1,"Pace car respects pit speed limit")
		if pace.phase == pace.Phase.PARKED:
			break
	check(green,"Formation reaches green")
	check(pulled_away and max_speed>100.0,"Pace car accelerates away in Turn 3")
	check(min_gap > 10,"Pace car stays ahead of pole sitter")
	check(pace.phase == pace.Phase.PARKED,"Pace car returns to stall")
	check(pace.global_position.distance_to(main.get_node("MileOval").to_global(main.track_data.pace_car_box.origin))<.1,"Correct final bay position")
	print("PACE RESULT min_gap=",min_gap," max_speed=",max_speed," failures=",failures)
	main.free()
	quit(0 if failures.is_empty() else 1)
