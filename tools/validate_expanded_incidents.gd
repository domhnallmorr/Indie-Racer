extends SceneTree
const Rules = preload("res://game/race/incident_rules.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func fixture(mode: String = "everyone"):
	root.set_meta("roster_selection",{"session_mode":"race","race_laps":200,"file":"res://content/rosters/irl_2001/manifest.json","seed":1234,"incident_mode":mode,"ai_telemetry":false})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.player.set_physics_process(false)
	main.race_control.set_physics_process(false)
	main.incidents.set_physics_process(false)
	main.lap_timing.set_physics_process(false)
	main.session.show_green()
	main.incidents.failure_progress = INF
	main.incidents.debris_progress = INF
	for car in main.ai_cars:
		var driver = car.get_node("Driver")
		driver.set_physics_process(false)
		driver.race_plan.failure_progress = INF
	return main

func put_on_track(main, car, turn: bool) -> void:
	var control = main.race_control
	for metre in range(50,int(control.length)-50,5):
		car.global_position = car.track.to_global(control.circuit.sample_baked(float(metre)))
		if control.in_turn(car) == turn:
			car.player_state.is_in_pit_lane = false
			return
	check(false,"Track has requested turn/straight")

func run() -> void:
	if "--live" in OS.get_cmdline_user_args():
		await run_live()
		return
	var counts := {}
	var early := 0
	for seed_value in range(20000):
		var event := Rules.schedule(seed_value,200)
		check(event == Rules.schedule(seed_value,200),"Seed repeatability")
		if is_finite(event.progress):
			check(event.progress >= 10 and event.progress <= 190,"200-lap schedule bounds")
			counts[event.kind] = counts.get(event.kind,0)+1
			if event.progress <= 20:
				early += 1
	var total := 0
	for amount in counts.values():
		total += amount
	check(total > 3600 and total < 4400 and counts.size() == 7,"Single 20% budget includes all seven types")
	check(early < 300,"No early scheduling bias")
	var main = fixture()
	var control = main.race_control
	# AI puncture: complete its actual return route, full service, departure.
	var driver = main.ai_cars[0].get_node("Driver")
	driver.car.speed_mps = 70.0
	driver.race_plan.fail(driver,Rules.Kind.PUNCTURE)
	check(driver.race_plan.returning and driver.car.player_state.punctured and not control.active(),"AI puncture returns without yellow")
	for tick in range(18000):
		driver.elapsed += 1.0/30
		driver.race_plan.update(driver,1.0/30)
		if not driver.race_plan.returning:
			break
	check(not driver.race_plan.returning and driver.service_started >= 0 and not driver.race_plan.retired,"AI puncture reaches box and starts service")
	check(driver.car.collision_mask != 0 and driver.car.collision_layer != 0,"Repair restores physical ground contacts before departure")
	driver.elapsed = driver.service_started+driver.service_duration_seconds+1.0
	driver._update_race_service()
	check(not driver.car.player_state.punctured and is_equal_approx(driver.car.player_state.fuel_gal,driver.car.player_state.fuel_capacity_gal),"AI full service replaces tyres and fills tank")
	driver._physics_process(.016)
	check(driver.mode == driver.Mode.PIT_EXIT and driver.car.player_state.engine_running and not driver.race_plan.retired,"Repaired AI departs")
	for kind in [Rules.Kind.TURBO,Rules.Kind.ELECTRONICS]:
		var returning_driver = main.ai_cars[kind].get_node("Driver")
		returning_driver.race_plan.fail(returning_driver,kind)
		for tick in range(18000):
			returning_driver.race_plan.update(returning_driver,1.0/30)
			if not returning_driver.race_plan.returning:
				break
		check(returning_driver.race_plan.retired and not returning_driver.car.player_state.request_departure() and not control.active(),"Terminal pit return never rejoins or calls yellow")
	# Player puncture: own controls remain enabled; real stall service repairs it.
	check(main.incidents.trigger(Rules.Kind.PUNCTURE),"Player puncture triggers")
	check(main.player_state.tyre_grip_multiplier() < .7 and not control.active(),"Player puncture reduces grip without yellow")
	main.player.global_transform = main.player_state.stall_pose
	main.player.reset_dynamics()
	main.player_state._physics_process(.4)
	check(main.player_state.pit_stall_state == main.player_state.StallState.SERVICING,"Player puncture starts full service in own box")
	main.player_state._physics_process(14.0)
	check(not main.player_state.punctured and main.player_state.engine_running and main.player_state.incident_name.is_empty(),"Player puncture repaired and engine restarted")
	main.player_state.pit_stall_state = main.player_state.StallState.NONE
	check(main.incidents.trigger(Rules.Kind.TURBO),"Player turbo failure triggers")
	main.player_state._physics_process(.4)
	check(main.player.get_meta("retired",false) and not main.player_state.request_departure() and not control.active(),"Player turbo retires at box without yellow or repair")
	# Straight protection and turn-only crash; mechanical failure after restart.
	var crash_driver = main.ai_cars[8].get_node("Driver")
	put_on_track(main,crash_driver.car,false)
	crash_driver.race_plan.fail(crash_driver,Rules.Kind.CRASH)
	check(not crash_driver.race_plan.retired,"Crash rejected on straight")
	put_on_track(main,crash_driver.car,true)
	control.scripted_incident_until = 999
	crash_driver.race_plan.fail(crash_driver,Rules.Kind.CRASH)
	check(not crash_driver.race_plan.retired,"Crash waits during restart spacing")
	control.scripted_incident_until = -INF
	crash_driver.car.speed_mps = 70
	crash_driver.race_plan.fail(crash_driver,Rules.Kind.CRASH)
	check(crash_driver.race_plan.retired and control.active(),"Turn crash always DNF plus yellow")
	for tick in range(750):
		crash_driver.race_plan.update(crash_driver,1.0/30)
	check(crash_driver.race_plan.recovered and not crash_driver.car.player_state.request_departure(),"Crash recovers to box without rejoining")
	control._restart()
	var stopped = main.ai_cars[9].get_node("Driver")
	stopped.race_plan.fail(stopped,Rules.Kind.TRANSMISSION)
	check(stopped.race_plan.retired and control.active(),"Transmission always DNF, even just after restart")
	main.free()
	main = fixture()
	put_on_track(main,main.player,false)
	check(not main.incidents.trigger(Rules.Kind.CRASH),"Player cannot spin on a straight")
	put_on_track(main,main.player,true)
	main.player.speed_mps = 70
	check(main.incidents.trigger(Rules.Kind.CRASH) and main.player.get_meta("retired",false) and main.race_control.active(),"Player turn crash is DNF with caution")
	for tick in range(750):
		main.incidents._physics_process(1.0/30)
	check(main.incidents.motion.recovered and not main.player_state.request_departure(),"Player crash recovered and cannot restart")
	main.free()
	main = fixture()
	main.player.speed_mps = 60.0
	check(main.incidents.trigger(Rules.Kind.ENGINE) and main.race_control.active(),"Player engine failure calls caution")
	check(not main.player_state.engine_running and main.incidents.smoke.emitting,"Player engine stops and emits smoke")
	main.session.finish_race()
	for tick in range(900):
		main.incidents._physics_process(1.0/30)
	check(main.incidents.motion.recovered and not main.incidents.smoke.emitting and not main.player_state.request_departure(),"Player engine recovery completes after finish and remains terminal")
	main.free()
	for mode in ["off","ai_only"]:
		main = fixture(mode)
		main.incidents.failure_progress = 0.0
		main.incidents.debris_progress = 0.0
		main.incidents._physics_process(.016)
		check(not main.player.get_meta("retired",false) and main.player_state.incident_name.is_empty(),"Player excluded in "+mode)
		if mode == "off":
			var disabled = main.ai_cars[0].get_node("Driver")
			disabled.race_plan.failure_progress = 0.0
			disabled.race_plan.update(disabled,.016)
			check(not disabled.race_plan.retired and not main.race_control.active(),"Off disables AI and debris")
		else:
			check(main.race_control.active() and main.race_control.reason == "Debris on track","Rare debris can call yellow without retirement")
		main.free()
	print("EXPANDED INCIDENTS ","PASSED" if failures.is_empty() else failures,"; distribution=",counts)
	quit(0 if failures.is_empty() else 1)

func run_live() -> void:
	root.set_meta("roster_selection",{"session_mode":"race","race_laps":200,"file":"res://content/rosters/icr2_test/manifest.json","seed":1234,"incident_mode":"off","ai_telemetry":false})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.player.driving_enabled = false
	main.player.global_transform = main.player_state.stall_pose
	main.player.update_zone_state()
	main.session.show_green()
	main.pace_car.phase = main.pace_car.Phase.PARKED
	main.pace_car.global_transform = main.get_node("MileOval").global_transform*main.track_data.pace_car_box
	var driver = main.ai_cars[0].get_node("Driver")
	for car in main.ai_cars.slice(1):
		car.get_node("Driver").set_physics_process(false)
		car.global_transform = car.get_node("Driver").pit_box_pose
		car.update_zone_state()
	driver.index = driver.race.size()/2
	var tangent: Vector3 = (driver.race[driver.index+1]-driver.race[driver.index]).normalized()
	driver.car.global_transform = driver.car.track.global_transform*Transform3D(Basis.looking_at(tangent),driver.race[driver.index])
	driver.car.speed_mps = 65.0
	driver.car.update_zone_state()
	await physics_frame
	driver.race_plan.fail(driver,Rules.Kind.PUNCTURE)
	var saw_service := false
	var rejoined_lap := -1
	var raced_after_repair := false
	for tick in range(60*240):
		await physics_frame
		if tick%3600 == 3599:
			print("PUNCTURE LIVE tick=",tick," mode=",driver.mode," position=",driver.car.global_position," speed=",driver.car.speed_mps," laps=",main.lap_timing.entries[1].laps," expected=",main.lap_timing.entries[1].expected)
		saw_service = saw_service or driver.service_started >= 0
		check(not main.race_control.active() and not driver.race_plan.retired,"Puncture remains repairable and green")
		if saw_service and driver.mode == driver.Mode.RACING and not driver.car.player_state.punctured:
			if rejoined_lap < 0:
				rejoined_lap = main.lap_timing.entries[1].laps
			elif main.lap_timing.entries[1].laps > rejoined_lap:
				raced_after_repair = true
				break
	check(saw_service and raced_after_repair,"AI completes live puncture service, pit exit and another scored lap")
	print("LIVE PUNCTURE ","PASSED" if failures.is_empty() else failures,"; service=",saw_service," rejoined_lap=",rejoined_lap," mode=",driver.mode)
	main.free()
	quit(0 if failures.is_empty() else 1)
