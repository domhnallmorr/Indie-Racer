extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func run() -> void:
	root.size = Vector2i(1280,720)
	var menu = load("res://game/main/menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu._on_race_weekend_pressed()
	menu._on_setup_continue_pressed()
	for i in range(3): await process_frame
	var button = menu.get_node("Center/WeekendMenu/Panel/Margin/Layout/PrivateTesting")
	check(button.visible and button.text == "Private Testing","Private Testing menu entry")
	check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(menu.weekend_screen.get_global_rect()),"Weekend menu fits viewport")
	button.pressed.emit()
	await scene_changed
	check(root.get_meta("roster_selection").session_mode == "private_testing","Menu launches private session")
	for track in ["mile_oval","texas","michigan","indianapolis"]:
		if track != "mile_oval":
			# Private testing must not depend on successfully loading an AI roster.
			root.set_meta("roster_selection",{"session_mode":"private_testing","track_id":track,"file":"res://missing_roster.json"})
			change_scene_to_file("res://game/main/main.tscn")
			await scene_changed
		var main = current_scene
		for i in range(4): await physics_frame
		check(main.player.physics_ready and main.player.driving_enabled,track+": player ready")
		check(not main.ai_enabled and main.ai_cars.is_empty() and main.pace_car == null and not main.has_node("PaceCar"),track+": no AI or pace car")
		check(main.lap_timing.entries.size() == 1 and main.lap_timing.entries[0].car == main.player,track+": player-only timing")
		check(main.session.session_type == main.session.SessionType.PRIVATE_TESTING and main.session.status == main.session.Status.RUNNING,track+": session type/running")
		check(main.player_state.pit_stall_state == main.player_state.StallState.STOPPED,track+": starts in pit stall")
		check(main.player.can_adjust_aero() and main.get_node("PitMonitor").available(),track+": pit setup available")
		check(main.player_state.tyre_wear_active(),track+": practice tyre behaviour")
		var panel = main.get_node("HUD/RaceUI/Shell/Layout/Content/Pages/RosterPanel")
		check(panel.session_choice.selected == 3 and not panel.start.disabled,track+": restart selection retained")
		var controls = main.get_node("HUD/RaceUI/Shell/Layout/Content/Pages/ControlsPanel")
		var traction = controls.find_child("traction_control",true,false)
		check(traction != null,track+": assist controls available")
		if traction != null:
			traction.value = 65
			check(is_equal_approx(main.player.sim.p.traction_control,.65) and main.player.sim.p.stability_assistance == 0,track+": assist control changes only selected assist")
		main.player_state.request_departure()
		check(main.player_state.pit_stall_state != main.player_state.StallState.STOPPED,track+": departure permitted")
		var event := InputEventKey.new()
		event.keycode = KEY_R
		event.pressed = true
		main._unhandled_input(event)
		check(main.player.sim.u == 0 and main.player_state.pit_stall_state == main.player_state.StallState.STOPPED,track+": reset to pits")
		main.session.advance(3600)
		check(main.session.status == main.session.Status.FINISHED,track+": practice clock expires safely without pace car")
		print("PRIVATE TESTING checked: ",track)
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PRIVATE TESTING PASSED: menu launch, four tracks, solo field, pit setup, assists, reset and clock.")
	quit(0 if failures.is_empty() else 1)
