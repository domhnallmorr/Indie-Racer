extends SceneTree
## Reproduce the first five cars missing the opening, on both reported tracks.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func place(main, lead_at: float) -> void:
	var control = main.race_control
	for i in range(main.ai_cars.size()):
		var car = main.ai_cars[i]
		var driver = car.get_node("Driver")
		var at: float = fposmod(lead_at-i*control.QUEUE_GAP,control.length)
		car.global_position = car.track.to_global(control.circuit.sample_baked(at))
		car.speed_mps = main.track_data.pace_speed_kph/3.6
		car.player_state.is_in_pit_lane = false
		driver.mode = driver.Mode.FORMATION
		driver.index = 0
		var local: Vector3 = car.track.to_local(car.global_position)
		for j in range(driver.race.size()):
			if local.distance_squared_to(driver.race[j]) < local.distance_squared_to(driver.race[driver.index]):
				driver.index = j
		control.progress[car] = lead_at-i*control.QUEUE_GAP
		control.last_position[car] = control.position_of(car)
	main.pace_car.global_position = main.get_node("MileOval").to_global(control.circuit.sample_baked(fposmod(lead_at+control.QUEUE_GAP,control.length)))
	main.pace_car.caution_picked_up = true

func run() -> void:
	for track_id in ["mile_oval","texas"]:
		root.set_meta("roster_selection",{"track_id":track_id,"session_mode":"race","race_laps":80,"file":"res://content/rosters/icr2_full/manifest.json","seed":42})
		var main = load("res://game/main/main.tscn").instantiate()
		root.add_child(main)
		main.process_mode = Node.PROCESS_MODE_DISABLED
		main.session.show_green()
		main.player.global_transform = main.get_node("MileOval").global_transform*main.track_data.pit_box_transform()
		main.player.update_zone_state()
		var control = main.race_control
		control.call_caution("Pit opening regression")
		control.queue.assign(main.ai_cars)
		for car in main.ai_cars:
			car.player_state.fuel_gal = 8.0
		var driver = main.ai_cars[0].get_node("Driver")
		var entry_at: float = control.circuit.get_closest_offset(driver.race[driver.pit_entry_index])
		place(main,entry_at-50.0)
		check(not control._pit_opening_safe(),track_id+": leader needs advance notice before the decision window")
		place(main,entry_at-150.0)
		check(control._pit_opening_safe(),track_id+": opening before the whole train reaches entry is allowed")
		var lead_at: float = entry_at+125.0
		place(main,lead_at)
		control.elapsed = 20.0
		check(control._gathered(),track_id+": seeded field is gathered")
		control._physics_process(0.0)
		check(control.phase == control.Phase.CLOSED,track_id+": pits stay closed with leaders past decision point")
		# Advance the complete queue until opening is fair; no natural physics
		# or timing variability can hide the original mid-queue opening bug.
		var opened := false
		for step in range(int(control.length/5.0)+1):
			lead_at += 5.0
			place(main,lead_at)
			control._physics_process(0.0)
			if control.phase == control.Phase.OPEN:
				opened = true
				break
		check(opened,track_id+": opening is available within one lap")
		# Feed actual driver decision windows in track order, recording which
		# cars commit first. Each must stop on this same pass, front to back.
		var entrants: Array = []
		for step in range(int(control.length/5.0)+1):
			lead_at += 5.0
			place(main,lead_at)
			for car in main.ai_cars:
				if car in entrants:
					continue
				var ai = car.get_node("Driver")
				ai._update_race_pits()
				if ai.mode == ai.Mode.PIT_ENTRY:
					entrants.append(car)
			if entrants.size() == main.ai_cars.size():
				break
		check(entrants == main.ai_cars,track_id+": every car gets the first stop in queue order")
		print("PIT OPENING ",track_id," entrants=",entrants.size(),"/",main.ai_cars.size())
		main.free()
	print("CAUTION PIT OPENING ","PASSED" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
