extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 8
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	var seen_unlimited := [false,false]
	var seen_limiter := [false,false]
	var last_modes := [-1,-1]
	if main.ai_cars.size() != 2:
		push_error("Expected two AI cars")
		quit(1)
		return
	for step in range(5400):
		await physics_frame
		for i in range(2):
			var car = main.ai_cars[i]
			var driver = car.get_node("Driver")
			if driver.mode != last_modes[i]:
				print("%s mode=%s t=%.1f position=%s" % [car.name,driver.mode,driver.elapsed,car.position])
				last_modes[i] = driver.mode
			if car.player_state.is_in_pit_speed_zone:
				if car.speed_mps > 80.0/3.6+.01:
					failures.append("Limiter exceeded")
				if car.speed_mps > 15:
					seen_limiter[i] = true
			elif driver.mode == driver.Mode.PIT_EXIT and car.speed_mps > 80.0/3.6+1:
				seen_unlimited[i] = true
		if step % 900 == 899:
			for car in main.ai_cars:
				var driver = car.get_node("Driver")
				print("%s t=%.1f idx=%d speed=%.1f laps=%d pos=%s error=%.2f" % [car.name,driver.elapsed,driver.index,car.speed_mps*3.6,driver.laps,car.position,driver.max_line_error_m])
	for i in range(2):
		var car = main.ai_cars[i]
		var driver = car.get_node("Driver")
		if not seen_limiter[i] or not seen_unlimited[i]:
			failures.append(car.name+" did not exercise limited/unlimited exit")
		if driver.mode != driver.Mode.RACING or driver.laps < 2:
			failures.append(car.name+" did not complete repeated race laps")
		if driver.max_line_error_m > 5:
			failures.append(car.name+" left race-line corridor")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("AI VALIDATION PASSED: two departures, limiter release, merges and repeated laps.")
	quit(0 if failures.is_empty() else 1)
