extends SceneTree
## Reference AI envelope and the five-second launch/restart handover.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func validate() -> void:
	root.set_meta("roster_selection",{"track_id":"texas","file":"res://content/rosters/irl_2001/manifest.json","seed":42,"session_mode":"race"})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.player.telemetry.stop()
	var car = main.ai_cars[0]
	var driver = car.get_node("Driver")
	var craft = driver.racecraft
	driver.rivals.clear()
	driver.mode = 2
	var previous := INF
	for kph in range(0,451):
		var acceleration: float = car.available_acceleration(kph/3.6)
		check(acceleration > 0 and acceleration <= previous,"Envelope must remain positive and decrease with speed")
		previous = acceleration
	check(car.available_acceleration(280.0/3.6) <= 4.5,"Fifth-gear acceleration exceeds player reference envelope")
	check(car.available_acceleration(320.0/3.6) < 3.0,"High-speed acceleration has not tapered")
	# Repeat begin_green_launch as race control does on a later restart, with
	# different tick rates. Compare the actual capped speed increment on either
	# side of expiry, rather than just checking the authored curve points.
	for hz in [60,120]:
		var dt: float = 1.0/hz
		for initial_kph in [100.0,180.0]:
			car.speed_mps = initial_kph/3.6
			craft.begin_green_launch(0.0,NAN,0,car.speed_mps)
			var before := 0.0
			var after := 0.0
			for tick in range(hz*6):
				craft.update(driver,dt)
				var request := 400.0/3.6
				if craft.green_launch_acceleration_remaining_s > 0:
					request = minf(request,craft.green_launch_speed_cap_mps)
				var speed: float = car.speed_mps
				car.speed_mps = move_toward(speed,request,car.available_acceleration(speed)*dt)
				var acceleration: float = (car.speed_mps-speed)/dt
				if tick == hz*5-2: before = acceleration
				if tick == hz*5: after = acceleration
			check(absf(after-before) < .15,"Launch expiry causes an acceleration step")
			print("ACCELERATION handover hz=",hz," initial_kph=",initial_kph," before=",before," after=",after)
	main.free()
	for failure in failures:
		push_error(failure)
	print("AI ACCELERATION PASSED" if failures.is_empty() else "AI ACCELERATION FAILED")
	quit(0 if failures.is_empty() else 1)
