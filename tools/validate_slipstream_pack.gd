extends SceneTree
## Start a seeded field on track to isolate towing from pit-release scheduling.
func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	Engine.physics_ticks_per_second = 480
	Engine.time_scale = 8
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_seed = 1234
	root.add_child(main)
	var fixture = load("res://tools/validate_racecraft.gd").new()
	var without_tow := "--without-tow" in OS.get_cmdline_user_args()
	for i in range(main.ai_cars.size()):
		var car = main.ai_cars[i]
		var driver = car.get_node("Driver")
		driver.practice_cycle = false
		driver.race_pit_cycle = false
		car.slipstream_enabled = not without_tow
		car.player_state.request_departure()
		fixture.place(car,100.0+floorf(i/3.0)*driver.race_length_m/5.0+(i%3)*22.0,0.0,70.0)
	var tow_ticks := 0
	var contacts := 0
	var edge_ticks := 0
	var maximum_reduction := 0.0
	var maximum_speed := 0.0
	var maximum_offset := 0.0
	for tick in range(3600):
		await physics_frame
		for car in main.ai_cars:
			var driver = car.get_node("Driver")
			maximum_reduction = maxf(maximum_reduction,car.slipstream_drag_reduction)
			maximum_speed = maxf(maximum_speed,car.speed_mps*3.6)
			if car.slipstream_drag_reduction > .01:
				tow_ticks += 1
			var offset: float = absf(driver.racecraft.coordinates(driver,car).y)
			maximum_offset = maxf(maximum_offset,offset)
			if offset > 9.0:
				edge_ticks += 1
			if car.car_contact_this_step:
				contacts += 1
	var valid := maximum_reduction <= .180001 and edge_ticks == 0 and contacts == 0 and (tow_ticks > 0 if not without_tow else tow_ticks == 0)
	print("SLIPSTREAM PACK ",JSON.stringify({"without_tow":without_tow,"cars":main.ai_cars.size(),"tow_ticks":tow_ticks,"contacts":contacts,"edge_ticks":edge_ticks,"max_reduction":maximum_reduction,"peak_kph":maximum_speed,"max_offset_m":maximum_offset,"passed":valid}))
	fixture.free()
	main.free()
	quit(0 if valid else 1)
