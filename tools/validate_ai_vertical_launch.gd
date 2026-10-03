extends SceneTree
const DT := 1.0/60.0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func run() -> void:
	root.set_meta("roster_selection",{"track_id":"texas","session_mode":"race","file":"res://content/rosters/irl_2001/manifest.json","seed":1562647631,"ai_telemetry":true})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.player.telemetry.stop()
	var car = main.get_node("AI_Lazier")
	var driver = car.get_node("Driver")
	main.player.track.process_mode = Node.PROCESS_MODE_ALWAYS
	car.process_mode = Node.PROCESS_MODE_ALWAYS
	car.set_physics_process(false)
	driver.set_physics_process(false)
	for other in [main.player]+main.ai_cars:
		if other != car: other.global_position = Vector3(0,-1000,0)
	car.player_state.pit_stall_state = car.player_state.StallState.NONE
	driver.race_pit_cycle = false
	driver.practice_cycle = false
	await physics_frame
	await physics_frame
	# Replay the measured launch energy away from any road support. A mesh
	# solver impulse must not become a 15-second, 290-metre ballistic arc.
	car.global_position = Vector3(190,20,233)
	car.rotation = Vector3(0,-1.3,0)
	car.speed_mps = 374.0/3.6
	car.velocity = Vector3(0,75,0)
	var initial_y: float = car.global_position.y
	car.reference_step(DT,car.speed_mps,0)
	check(car.global_position.y <= initial_y,"Unsupported car retained upward solver impulse")
	check(car.velocity.y < 0,"Unsupported car must start descending")
	car.velocity.y = -12
	initial_y = car.global_position.y
	car.reference_step(DT,car.speed_mps,0)
	check(car.velocity.y < -12 and car.global_position.y < initial_y,"Existing downward fall was lost")
	# Revisit the actual takeoff approach, then drive two complete laps across
	# both bank profiles and all transitions at race speed.
	car.reset_dynamics()
	car.global_position = Vector3(143.318420,.763328,244.190155)
	car.rotation = Vector3(0,atan2(-11.838501,2.513977),0)
	car.speed_mps = 373.47/3.6
	driver.mode = driver.Mode.RACING
	driver.index = 73
	await physics_frame
	await physics_frame
	var peak := 0.0
	var grounded_ticks := 0
	for tick in range(3000):
		driver._physics_process(DT)
		peak = maxf(peak,car.global_position.y)
		if car.is_on_floor(): grounded_ticks += 1
		check(car.global_position.y > -1 and car.global_position.y < 10,"Car left road height envelope at tick %d" % tick)
		if not failures.is_empty(): break
		await physics_frame
	check(driver.laps >= 2,"Did not complete two laps")
	check(grounded_ticks > 2700,"Lost sustained road support")
	driver.diagnostic.flush()
	var recorded := FileAccess.open(driver.diagnostic.get_path(),FileAccess.READ)
	check(recorded.get_csv_line().size() == 22,"Missing expanded telemetry header")
	var rows := 0
	while not recorded.eof_reached():
		var row := recorded.get_csv_line()
		if row.size() == 1 and row[0].is_empty(): continue
		check(row.size() == 22,"Telemetry row does not match header")
		rows += 1
	check(rows > 400,"Missing driving telemetry")
	recorded.close()
	print("AI VERTICAL LAUNCH: peak_y=",peak," grounded_ticks=",grounded_ticks," laps=",driver.laps," failures=",failures)
	main.free()
	quit(0 if failures.is_empty() else 1)
