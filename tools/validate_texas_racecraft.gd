extends SceneTree
## Run with --headless --fixed-fps 60; formation plus one minute of racing.
func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	Engine.physics_ticks_per_second = 60
	var track_id := "texas"
	var seed_value := 42
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--track="): track_id = argument.trim_prefix("--track=")
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
	root.set_meta("roster_selection",{"track_id":track_id,"file":"res://content/rosters/irl_2001/manifest.json","seed":seed_value,"session_mode":"race","race_laps":20})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.player.global_transform = main.player.track.global_transform*main.track_data.pit_box_transform()
	main.player.reset_dynamics()
	var green := -1
	var contacts := 0
	var edge_ticks := 0
	var max_offset := 0.0
	var passes := 0
	var attempts := 0
	var established_pass_ticks := 0
	for car in main.ai_cars:
		car.get_node("Driver").race_plan.failure_progress = INF
	for tick in range(10000):
		await physics_frame
		if main.session.status != main.session.Status.RUNNING:
			continue
		if green < 0:
			green = tick
			print("TEXAS RACECRAFT green at ",tick/60.0)
		passes = 0
		attempts = 0
		for car in main.ai_cars:
			var driver = car.get_node("Driver")
			if car.car_contact_this_step:
				contacts += 1
			var offset: float = absf(driver.racecraft.coordinates(driver,car).y)
			max_offset = maxf(max_offset,offset)
			if offset > 9.0:
				edge_ticks += 1
			passes += driver.racecraft.passes
			attempts += driver.racecraft.attempts
			if driver.racecraft.opponent != null and absf(driver.racecraft.lane) > .8:
				established_pass_ticks += 1
		if (tick-green)%1200 == 0:
			print("TEXAS RACECRAFT seconds=",(tick-green)/60.0," passes=",passes," attempts=",attempts," contacts=",contacts," edge_ticks=",edge_ticks)
		if tick-green >= 3600:
			break
	var result := {"green":green>=0,"passes":passes,"attempts":attempts,"established_pass_ticks":established_pass_ticks,"contacts":contacts,"edge_ticks":edge_ticks,"max_offset_m":max_offset}
	print("TEXAS RACECRAFT RESULT ",JSON.stringify(result))
	result.track = track_id
	result.seed = seed_value
	var file := FileAccess.open("res://builds/"+track_id+"_racecraft_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	main.free()
	# This evenly matched pack must make usable moves, not guarantee that an
	# attacker establishes safe returning clearance within one minute.
	# The separate slower-leader queue fixture requires a completed pass.
	quit(0 if green >= 0 and attempts > 0 and established_pass_ticks > 60 and contacts == 0 and edge_ticks == 0 else 1)
