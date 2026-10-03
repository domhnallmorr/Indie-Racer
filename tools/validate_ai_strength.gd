extends SceneTree
## Run headless with --fixed-fps 60. Same seeded Texas cars at three strengths.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var means: Array[float] = []
	var fixture = load("res://tools/validate_racecraft.gd").new()
	for strength in [90,100,120]:
		root.set_meta("roster_selection",{"track_id":"texas","file":"res://content/rosters/icr2_test/manifest.json","seed":1234,"ai_strength":strength,"ai_telemetry":false})
		var main = load("res://game/main/main.tscn").instantiate()
		root.add_child(main)
		var samples: Array = [[],[]]
		var max_offset := 0.0
		for car in main.ai_cars:
			var driver = car.get_node("Driver")
			assert(driver.profile_ready)
			assert(is_equal_approx(driver.strength_speed_scale,1.0+(strength-100)*.0025))
			var baseline: float = driver.base_lap_target_s+driver.fuel_pace_penalty_s()+car.player_state.tyre_pace_penalty_s()
			assert(is_equal_approx(driver.target_lap_s(),baseline/driver.strength_speed_scale))
			driver.practice_cycle = false
			driver.rivals.clear()
			car.collision_layer = 0
			fixture.place(car,100,0,85)
		for tick in range(7200):
			await physics_frame
			for i in range(main.ai_cars.size()):
				var car = main.ai_cars[i]
				var driver = car.get_node("Driver")
				var entry: Dictionary = main.lap_timing.entries[i+1]
				if entry.laps > samples[i].size():
					samples[i].append(entry.last)
				max_offset = maxf(max_offset,absf(driver.racecraft.coordinates(driver,car).y))
		var total := 0.0
		var count := 0
		for laps in samples:
			if laps.size() < 4:
				failures.append("Insufficient Texas laps at %d" % strength)
			for lap in laps.slice(1):
				total += lap
				count += 1
		means.append(total/maxi(1,count))
		if max_offset > 9.0:
			failures.append("Texas road boundary exceeded at %d" % strength)
		print("STRENGTH ",strength," mean_lap_s=",means[-1]," max_offset_m=",max_offset," laps=",samples)
		main.free()
		await process_frame
	fixture.free()
	if not (means[0] > means[1]+.25 and means[1] > means[2]+.5):
		failures.append("Strength must produce measurably quicker Texas laps")
	var driver = load("res://game/ai/oval_driver.gd").new()
	driver.configure_strength(0)
	assert(is_equal_approx(driver.strength_speed_scale,.975))
	driver.configure_strength(999)
	assert(is_equal_approx(driver.strength_speed_scale,1.05))
	driver.free()
	print("AI STRENGTH PASSED" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
