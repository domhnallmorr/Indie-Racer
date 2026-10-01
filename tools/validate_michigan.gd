extends SceneTree
## Runtime probe: real road contacts, AI initialization, circulation and pit service.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	Engine.physics_ticks_per_second = 480
	Engine.time_scale = 8
	root.set_meta("roster_selection",{"track_id":"michigan","file":"res://content/rosters/icr2_test/manifest.json","seed":42,"session_mode":"race","race_laps":20})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	var circuit: Node3D = main.get_node("MileOval")
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/michigan/ai/reference_paths.json"))
	for sample in [[0,12.0],[410,18.0],[810,5.0],[1200,18.0]]:
		var p: Array = reference.reference_path[sample[0]]
		var at := circuit.to_global(Vector3(p[0],p[1],p[2]))
		var hit := root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*12,at-Vector3.UP*12,1))
		if hit.is_empty():
			failures.append("Missing road collision")
		else:
			var angle := rad_to_deg(acos(clampf(hit.normal.y,-1,1)))
			print("MICHIGAN bank ",sample[0]," = ",angle)
			if absf(angle-sample[1]) > .25:
				failures.append("Bank mismatch")
	for car in main.ai_cars:
		var driver = car.get_node("Driver")
		driver.race_plan.failure_progress = INF
		if not driver.profile_ready or not driver.racecraft.enabled:
			failures.append("Invalid AI profile/corridor")
	if main.ai_cars.is_empty():
		failures.append("No AI cars")
	if not failures.is_empty():
		print(failures)
		quit(1)
		return
	for tick in range(10800):
		await physics_frame
		if main.session.status == main.session.Status.RUNNING:
			break
	if main.session.status != main.session.Status.RUNNING:
		failures.append("Formation never reached green")
	print("MICHIGAN formation status ",main.session.status)
	main.player.global_transform = circuit.global_transform*main.track_data.pit_box_transform(0)
	main.player.reset_dynamics()
	for tick in range(6000):
		await physics_frame
	for entry in main.lap_timing.entries.slice(1):
		print("MICHIGAN laps ",entry.name," ",entry.laps," best ",entry.best)
		if entry.laps < 1:
			failures.append("No completed lap: "+entry.name)
	var driver = main.ai_cars[0].get_node("Driver")
	driver._begin_pit_entry()
	var served := false
	var rejoined := false
	for tick in range(14400):
		await physics_frame
		if tick%1800 == 1799:
			print("MICHIGAN pit mode ",driver.mode," speed ",driver.car.speed_mps*3.6," position ",driver.car.global_position," stops ",driver.completed_fuel_stops)
		served = served or driver.completed_fuel_stops > 0
		if served and driver.mode == driver.Mode.RACING:
			rejoined = true
			break
	if not rejoined:
		failures.append("Pit service/rejoin failed")
	print("MICHIGAN VALIDATION ",JSON.stringify({"failures":failures,"served":served,"rejoined":rejoined}))
	main.free()
	quit(0 if failures.is_empty() else 1)
