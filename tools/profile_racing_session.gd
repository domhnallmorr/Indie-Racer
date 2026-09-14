extends SceneTree
## Rendered moving field comparison. Run by itself, with no other benchmarks.
func _initialize() -> void:
	call_deferred("profile")

func profile() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	var results: Array = []
	for before in [true,false]:
		for count in [8,15]:
			var main = load("res://game/main/main.tscn").instantiate()
			main.roster_seed = 1234
			root.add_child(main)
			main.player.driving_enabled = false
			main.get_node("DisplayCar/Cockpit").deactivate()
			var fixture = load("res://tools/validate_racecraft.gd").new()
			for i in range(main.ai_cars.size()):
				var car = main.ai_cars[i]
				var driver = car.get_node("Driver")
				driver.release_delay = 1000000
				if before:
					driver.racecraft = preload("res://tools/profile_racecraft.gd").ExhaustiveRacecraft.new()
					driver.racecraft.configure(JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/mile_oval/ai/racing_corridor.json")),driver.race)
				if i < count:
					fixture.place(car,100+i*14,0,65)
			var camera = main.get_node("InspectionCamera")
			camera.followed_ai = 0
			camera.distance = 18
			camera.make_current()
			var times: Array[float] = []
			var physics := 0.0
			var started := Time.get_ticks_usec()
			var last := started
			while Time.get_ticks_usec()-started < 12000000:
				await process_frame
				var now := Time.get_ticks_usec()
				if now-started > 2000000:
					times.append((now-last)/1000.0)
					physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
				last = now
			times.sort()
			var item := {"original_scans":before,"racing":count,"frames":times.size(),"median_frame_ms":times[times.size()/2],"p95_frame_ms":times[int(times.size()*.95)],"physics_ms":physics/times.size()}
			results.append(item)
			print(JSON.stringify(item))
			fixture.free()
			main.free()
			await process_frame
	var file := FileAccess.open("res://builds/racing_session_profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	file.close()
	quit()
