extends SceneTree
## Run headless with --fixed-fps 120. Full formation and 12 seconds at green.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Engine.physics_ticks_per_second = 120
	root.set_meta("roster_selection",{"file":"res://content/rosters/icr2_full/manifest.json","seed":42,"session_mode":"race"})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	# No human is driving this headless run: park the player in its pit box so
	# the field does not hit a stationary grid car on its first racing lap.
	main.player.global_transform = main.get_node("MileOval").global_transform*main.track_data.pit_box_transform()
	main.player.reset_dynamics()
	var green_tick := -1
	var contacts := 0
	var min_separation := INF
	var stagger_verified := false
	for tick in range(18000):
		await physics_frame
		if main.session.status != main.session.Status.RUNNING:
			continue
		if green_tick < 0:
			green_tick = tick
			print("GREEN at ",tick/120.0)
		var elapsed := (tick-green_tick)/120.0
		if elapsed >= .8 and not stagger_verified:
			# Row 7 is held for .7 seconds while row 0 is already accelerating.
			stagger_verified = main.ai_cars[0].speed_mps > main.ai_cars[14].speed_mps+1.0
		for car in main.ai_cars:
			for c in range(car.get_slide_collision_count()):
				if car.get_slide_collision(c).get_collider() in main.ai_cars:
					contacts += 1
		for i in range(main.ai_cars.size()):
			var first = main.ai_cars[i]
			var driver = first.get_node("Driver")
			var p: Vector2 = driver.racecraft.coordinates(driver,first)
			for j in range(i+1,main.ai_cars.size()):
				var q: Vector2 = driver.racecraft.coordinates(driver,main.ai_cars[j])
				var gap: float = fposmod(p.x-q.x+driver.race_length_m*.5,driver.race_length_m)-driver.race_length_m*.5
				if absf(gap) < 4.5:
					min_separation = minf(min_separation,absf(p.y-q.y))
		if (tick-green_tick)%600 == 0:
			var rows: Array = []
			for i in range(2):
				var car = main.ai_cars[i]
				var d = car.get_node("Driver")
				rows.append({"car":i,"lateral":d.racecraft.coordinates(d,car).y,"lane":d.racecraft.lane,"target":d.racecraft.target_lane,"speed":car.speed_mps,"error":d.current_line_error,"state":d.racecraft.state})
			print("LAUNCH ",elapsed," ",JSON.stringify(rows))
		if elapsed >= 12.0:
			break
	print("LAUNCH RESULT green=",green_tick>=0," contact_frames=",contacts," minimum_overlap_separation_m=",min_separation," row_stagger=",stagger_verified)
	main.free()
	quit(0 if green_tick>=0 and contacts==0 and min_separation>3.0 and stagger_verified else 1)
