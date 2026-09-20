extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	for scenario in ["normal","before_entry","after_entry","slow","bicycle"]:
		var roster := "default" if scenario == "bicycle" else "icr2_test"
		root.set_meta("roster_selection",{"session_mode":"race","race_laps":50,"file":"res://content/rosters/"+roster+"/manifest.json","seed":1234})
		var main = load("res://game/main/main.tscn").instantiate()
		root.add_child(main)
		for body in main.find_children("*","CollisionObject3D",true,false):
			body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
		main.process_mode = Node.PROCESS_MODE_DISABLED
		await physics_frame
		main.session.show_green()
		main.player.global_transform = main.get_node("MileOval").global_transform*main.track_data.pit_box_transform()
		main.player.update_zone_state()
		var car = main.ai_cars[0]
		var driver = car.get_node("Driver")
		var plan = driver.race_plan
		var rival = main.ai_cars[1].get_node("Driver")
		rival.race_plan.failure_progress = INF
		var at_index: int = driver.race.size()/2
		if scenario == "before_entry":
			at_index = posmod(driver.pit_approach_join_index-2,driver.race.size())
		elif scenario == "after_entry":
			at_index = (driver.pit_approach_join_index+2)%driver.race.size()
		driver.index = at_index
		var tangent: Vector3 = (driver.race[(at_index+1)%driver.race.size()]-driver.race[at_index]).normalized()
		car.global_transform = car.track.global_transform*Transform3D(Basis.looking_at(tangent),driver.race[at_index])
		car.speed_mps = 1.0 if scenario == "slow" else 65.0
		car.update_zone_state()
		main.lap_timing.entries[1].previous = car.track.to_local(car.global_position)
		await physics_frame
		plan.failure_type = plan.FailureType.OTHER
		plan.failure_progress = 0.0
		var start: Vector3 = car.global_position
		driver._physics_process(1.0/60)
		check(plan.returning and not plan.retired,scenario+": scheduled failure starts return before retirement")
		check(car.global_position.distance_to(start)<2.0,scenario+": no teleport on failure")
		check(car.player_state.engine_running and plan.smoke == null,scenario+": engine remains on, no smoke")
		main.get_node("InspectionCamera").followed_ai = 0
		main._update_hud()
		check(main.get_node("HUD/Panel/Label").text.contains("RETURNING — OTHER"),scenario+": HUD names Other return")
		check(main.race_control.caution_count == 0 and not main.race_control.active(),scenario+": no yellow")
		check(car.get_meta("pit_ghost") and car.collision_layer == 0,scenario+": slow return does not block racing traffic")
		if scenario == "before_entry":
			check(driver.pit_entry_lane_distance > driver.race_length_m*.8,"Late failure takes another inside lap")
		var speed_violations := 0
		var largest_step := 0.0
		var deepest := 100.0
		var checked_inside := false
		var ticks := 0
		for tick in range(60*180):
			if scenario == "normal":
				await physics_frame
			ticks = tick
			var previous: Vector3 = car.global_position
			driver._physics_process(1.0/60)
			if scenario == "normal":
				rival._physics_process(1.0/60)
			main.lap_timing._physics_process(1.0/60)
			var movement: Vector3 = car.global_position-previous
			largest_step = maxf(largest_step,Vector2(movement.x,movement.z).length())
			deepest = minf(deepest,car.track.to_local(car.global_position).y)
			if car.player_state.is_in_pit_speed_zone and car.speed_mps > main.track_data.speed_limit_kph/3.6+.05:
				speed_violations += 1
			if not checked_inside and plan.return_distance > 160 and plan.return_distance < driver.pit_entry_lane_distance-150 and driver.racecraft.enabled:
				var coordinates: Vector2 = driver.racecraft.coordinates(driver,car)
				check(absf(coordinates.y+6.5)<.3,scenario+": follows inside line")
				checked_inside = true
			if scenario == "after_entry" and tick == 180:
				main.race_control.call_caution("Unrelated incident")
				check(not car in main.race_control.queue,"Withdrawing car excluded from unrelated caution queue")
				check(not main.race_control._ai_pitting(),"Limp-home return does not delay restart")
				main.session.finish_race()
			if plan.retired:
				break
		check(plan.retired and plan.recovered and not plan.returning,scenario+": reaches permanent retirement")
		check(car.global_transform.is_equal_approx(driver.pit_box_pose),scenario+": parked in assigned box")
		check(not car.player_state.engine_running and car.speed_mps == 0,scenario+": engine shuts down at box")
		check(driver.completed_fuel_stops == 0 and driver.service_started < 0,scenario+": no fuel service or rejoin")
		check(speed_violations == 0 and largest_step < 2.0 and deepest > -1.0,scenario+": continuous grounded return with pit speed limit")
		var entry: Dictionary = main.lap_timing.entries[1]
		check(entry.get("retirement_reason","") == "Other" and entry.get("retired",false),scenario+": classification reason is Other")
		main._update_hud()
		check(main.get_node("HUD/Panel/Label").text.contains("OUT — OTHER"),scenario+": HUD names Other retirement")
		var final_laps: int = entry.laps
		for tick in range(120):
			driver._physics_process(1.0/60)
			main.lap_timing._physics_process(1.0/60)
		check(entry.laps == final_laps and car.global_transform.is_equal_approx(driver.pit_box_pose),scenario+": retirement remains final")
		check(main.race_control.caution_count == (1 if scenario == "after_entry" else 0),scenario+": no additional yellow")
		if scenario == "normal":
			# The static grid starts before the initial timing-line crossing;
			# allow the healthy car its out-lap as well as a complete timed lap.
			for tick in range(60*30):
				await physics_frame
				rival._physics_process(1.0/60)
				main.lap_timing._physics_process(1.0/60)
			print("GREEN TRAFFIC laps=",main.lap_timing.entries[2].laps," mode=",rival.mode," speed=",rival.car.speed_mps," position=",rival.car.global_position)
			check(main.lap_timing.entries[2].laps >= 1 and rival.mode == rival.Mode.RACING,"Other cars keep racing and completing laps under green")
		print("OTHER ",scenario," return_s=",ticks/60.0," largest_step_m=",largest_step," pit_violations=",speed_violations)
		main.free()
	print("OTHER RETIREMENTS ","PASSED" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
