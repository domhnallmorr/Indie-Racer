extends SceneTree
## Verify both formation rows remain on the same physical path at green.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.set_meta("roster_selection",{"file":"res://content/rosters/icr2_full/manifest.json","seed":42,"session_mode":"race"})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	var driver = main.ai_cars[0].get_node("Driver")
	var craft = driver.racecraft
	var maximum_jump := 0.0
	for i in range(0,driver.race.size(),10):
		driver.index = i
		for side in [-3.0,3.0]:
			driver.formation_lane_m = side
			driver.mode = 3
			var formation: Vector3 = driver._formation_ahead(15.0)
			driver.mode = 2
			craft.begin_green_launch(0.0,side)
			maximum_jump = maxf(maximum_jump,formation.distance_to(craft.ahead(driver,15.0)))
	# Without traffic, the timer expires and the lane hold must actually release.
	driver.rivals.clear()
	craft.green_launch_lane_hold_remaining_s = 0.0
	driver.car.speed_mps = 60.0
	craft.update(driver,2.0)
	var released: bool = craft.launch_weight == 0.0
	# A rear row holds formation speed briefly, then uses the configured launch
	# acceleration cap rather than the AI car's normal 8 m/s² limit.
	craft.begin_green_launch(0.0,NAN,2,20.0)
	craft.nearby.clear()
	craft.update(driver,.1)
	var delayed: bool = is_equal_approx(craft.traffic_speed(driver,80.0),20.0)
	craft.update(driver,.1)
	craft.update(driver,.1)
	var capped: bool = is_equal_approx(craft.traffic_speed(driver,80.0),20.5)
	print("LAUNCH GEOMETRY max_target_jump_m=",maximum_jump," clear_lane_released=",released," row_delay=",delayed," acceleration_cap=",capped)
	main.free()
	quit(0 if maximum_jump < .001 and released and delayed and capped else 1)
