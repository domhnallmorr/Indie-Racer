extends SceneTree
func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	Engine.physics_ticks_per_second = 480
	Engine.time_scale = 8
	root.set_meta("roster_selection",{"track_id":"texas","file":"res://content/rosters/icr2_test/manifest.json","seed":42,"session_mode":"race","race_laps":20})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	var errors: Array[String] = []
	for car in main.ai_cars:
		car.get_node("Driver").race_plan.failure_progress = INF
	for tick in range(7200):
		await physics_frame
		if main.session.status == main.session.Status.RUNNING:
			break
	if main.session.status != main.session.Status.RUNNING:
		errors.append("Formation never reached green")
	else:
		print("TEXAS formation reached green")
	# The unattended player otherwise remains on the backstretch grid, directly
	# across the later pit merge. Clear that obstruction for the service test.
	main.player.global_transform = main.player.track.global_transform*main.track_data.pit_box_transform(0)
	main.player.reset_dynamics()
	var car: Node3D = main.ai_cars[0]
	var driver = car.get_node("Driver")
	driver._begin_pit_entry()
	var served := false
	var rejoined := false
	for tick in range(10800):
		await physics_frame
		served = served or driver.completed_fuel_stops > 0
		if served and driver.mode == driver.Mode.RACING:
			rejoined = true
			break
		if tick%3600 == 3599:
			print("TEXAS pit phase=",driver.mode," speed=",car.speed_mps*3.6," position=",car.global_position," served=",served)
	if not rejoined:
		errors.append("AI did not complete pit service and rejoin")
	print("TEXAS SESSION ",JSON.stringify({"errors":errors,"stops":driver.completed_fuel_stops,"rejoined":rejoined,"laps":main.lap_timing.entries[1].laps}))
	main.free()
	quit(0 if errors.is_empty() else 1)
