extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func validate() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	main.ai_enabled = false
	root.add_child(main)
	await process_frame
	var ui = main.get_node("HUD/RaceUI")
	var compact = main.get_node("HUD/Panel")
	var black_box = main.get_node("HUD/BlackBox")
	check(black_box.visible and black_box.active_page == 0,"Black box starts on Lap Timing")
	for index in range(3):
		var event := InputEventKey.new()
		event.keycode = KEY_F1 + index
		event.pressed = true
		black_box._unhandled_input(event)
		check(black_box.active_page == index and main.player.driving_enabled,"Black box shortcuts preserve driving input")
	black_box.tabs[0].pressed.emit()
	check(black_box.active_page == 0,"Clickable tabs change the black box page")
	var entry: Dictionary = main.lap_timing.entries[0]
	entry.armed = true
	entry.laps = 2
	entry.started = 10.0
	entry.last = 21.25
	entry.best = 20.5
	main.lap_timing.clock = 15.0
	black_box.refresh()
	check(black_box.lap_values["Current"].text == "0:05.000","Black box shows live current lap")
	check(black_box.lap_values["Last"].text == "0:21.250" and black_box.lap_values["Best"].text == "0:20.500","Black box shows completed lap times")
	main.player_state.fuel_gal = main.player_state.fuel_per_lap_gal * 2.0
	black_box.select_page(2)
	check(black_box.fuel_values["Est. laps left"].text == "2.0","Fuel range uses actual remaining fuel")
	check(black_box.fuel_values["Remaining"].modulate.g < 0.5,"Low fuel is highlighted")
	main.session.start_race(10)
	black_box.refresh()
	check(black_box.lap_values["Lap"].text == "—","Formation does not claim a timed lap")
	main.session.show_green()
	entry.laps = 2
	black_box.refresh()
	check(black_box.lap_values["To go"].text == "8","Race displays remaining laps")
	for index in range(7):
		var opponent := Node3D.new()
		main.add_child(opponent)
		var result := entry.duplicate()
		result.car = opponent
		result.name = "Opponent %d" % index
		result.laps = 3
		result.order = index + 1
		main.lap_timing.entries.append(result)
	black_box.select_page(1)
	check(black_box.standing_rows[4][1].text == "Player","Full field keeps the player visible near the back")
	check(black_box.lap_values["Position"].text == "8 / 8","Race position uses the complete field")
	main.session.finish_race()
	black_box.refresh()
	check(black_box.lap_values["To go"].text == "0","Finished race has zero laps to go")
	main.lap_timing.entries.resize(1)
	main.session.start_practice()
	black_box.select_page(2)
	check(not ui.visible and compact.visible,"Driving starts with the compact HUD")
	for page_name in ["session","timing","controls","diagnostics"]:
		ui.open_page(page_name)
		check(ui.visible and ui.active_page == page_name,"Navigation opens "+page_name)
		check(not compact.visible and not main.player.driving_enabled,"Open screens suppress driving and the compact HUD")
		check(not black_box.visible,"Full menu hides the black box")
		var visible_pages := 0
		for page in ui.pages.values():
			visible_pages += int(page.visible)
		check(visible_pages == 1,"Exactly one content screen is visible")
	ui.close_shell()
	check(not ui.visible and compact.visible and main.player.driving_enabled,"Drive restores the compact HUD and player input")
	check(black_box.visible and black_box.active_page == 2,"Drive restores the selected black box page")
	ui.open_page("timing")
	ui.toggle_page("timing")
	check(not ui.visible,"Selecting the active screen toggles back to driving")
	var wheel_panel = main.player.wheel_input.panel
	check(wheel_panel.is_ancestor_of(ui) == false,"Wheel setup remains owned by the input controller")
	check(wheel_panel.get_parent() == ui.pages["controls"].wheel_host,"Wheel setup is embedded in the controls screen")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("RACE UI PASSED: compact HUD, page navigation, driving suppression and embedded controls.")
	quit(0 if failures.is_empty() else 1)
