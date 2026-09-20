extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	root.set_meta("roster_selection",{"session_mode":"race","file":"res://content/rosters/icr2_full/manifest.json","seed":42})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.session.show_green()
	var control = main.race_control
	main.player.global_transform = main.get_node("MileOval").global_transform*main.track_data.pit_box_transform()
	main.player.update_zone_state()
	for i in range(main.ai_cars.size()):
		var car = main.ai_cars[i]
		var entry: Dictionary = main.lap_timing.entries[i+1]
		entry.retired = i >= 3
		car.set_meta("retired",i >= 3)
		if i < 3:
			car.global_position = car.track.to_global(control.circuit.sample_baked(200-i*40))
			car.update_zone_state()
			entry.previous = car.track.to_local(car.global_position)
			entry.laps = [6,4,5][i]
			entry.armed = true
			entry.expected = 1
	var lead = main.ai_cars[0]
	var lapper = main.ai_cars[1]
	var third = main.ai_cars[2]
	check(control.call_caution("Rules test"),"Yellow accepted during race")
	check(control.queue == [lead,lapper,third],"Lapped car stays in physical queue position")
	check(main.lap_timing.entries[2].laps == 4,"No free lap awarded")
	check(control.committed.has(main.player) and control.may_service(main.player),"Already in pits may complete service")
	control.committed.erase(main.player)
	main.player_state._physics_process(.5)
	check(main.player_state.pit_stall_state == main.player_state.StallState.NONE,"Closed pit arrival does not begin player service")
	var player_fuel: float = main.player_state.fuel_gal
	main.player_state.fuel_gal = main.player_state.fuel_per_lap_gal*.5
	main.player_state._physics_process(.5)
	check(main.player_state.pit_stall_state == main.player_state.StallState.SERVICING,"Emergency arrival begins player refuelling")
	main.player_state.pit_stall_state = main.player_state.StallState.NONE
	main.player_state.set_engine_running(true)
	main.player_state.fuel_gal = player_fuel
	main.player_state.fuel_burn_factor = control.FUEL_FACTOR
	var black_box = main.get_node("HUD/BlackBox")
	black_box.active_page = 2
	black_box.refresh()
	check(black_box.footer.text.contains("45%") and black_box.status.text.contains("YELLOW"),"Fuel panel explains yellow consumption and green range")
	main._update_hud()
	check(main.get_node("HUD/Panel/Label").text.contains("PITS CLOSED"),"HUD shows pit closure")
	check(not control.may_service(lead),"Closed pits deny normal new service")
	var saved: float = lead.player_state.fuel_gal
	lead.player_state.fuel_gal = lead.player_state.fuel_per_lap_gal*.5
	check(control.may_service(lead) and control.should_pit(lead.get_node("Driver")),"Emergency fuel stop allowed")
	lead.player_state.fuel_gal = saved
	control.progress[lapper] = control.progress[lead]+10.0
	check(control.target_speed(lapper) <= 3.0 and not control._gathered(),"Illegal pass must yield, never catch up an extra lap")
	control.progress[lapper] = control.progress[lead]-40.0
	# A later call cancels the restart and starts a fresh open-pit lap.
	control.phase = control.Phase.ONE_TO_GREEN
	check(not control.call_caution("Additional incident"),"Additional incident does not create duplicate caution")
	check(control.phase == control.Phase.OPEN and control.caution_count == 1,"Additional incident cancels one-to-green")
	control.commit_pit(lapper)
	check(control.queue == [lead,third] and control.may_service(lapper),"Pit commitment removes car from running train")
	main.lap_timing.clock = 123.0
	control._restart()
	check(main.lap_timing.clock == 123.0 and main.lap_timing.entries[2].laps == 4,"Restart preserves clock and lap scores")
	check(lead.get_node("Driver").mode == 2,"Restart releases formation driver")
	check(main.player_state.fuel_burn_factor == 1.0,"Restart restores player fuel burn")
	var first: Dictionary = main.lap_timing.entries[1]
	var second: Dictionary = main.lap_timing.entries[2]
	first.laps = 7
	second.laps = 7
	first.expected = 1
	second.expected = 1
	first.previous = Vector3(100,0,125)
	second.previous = Vector3(150,0,125)
	first.order = 0
	second.order = 1
	check(main.lap_timing.standings()[0] == second,"Cars within one sector rank by actual progress, not original grid")
	# An incident can happen while every survivor is already in the pits.
	for car in [lead,lapper,third]:
		car.global_transform = car.get_node("Driver").pit_box_pose
		car.update_zone_state()
	check(control.call_caution("All survivors pitting"),"Yellow may begin with no on-track leader")
	check(control.queue.is_empty() and control.may_service(lead),"Existing pit cars remain eligible for service")
	control._restart()
	main.session.session_type = main.session.SessionType.PRACTICE
	check(not control.call_caution(),"Practice never deploys caution")
	main.session.session_type = main.session.SessionType.RACE
	main.session.finish_race()
	check(not control.call_caution(),"Finished race rejects caution")
	print("CAUTION RULES ","PASSED" if failures.is_empty() else failures)
	main.free()
	quit(0 if failures.is_empty() else 1)
