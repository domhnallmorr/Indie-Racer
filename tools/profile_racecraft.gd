extends SceneTree
## Cost of traffic/planning in mixed pit fields and a fully populated track.
class ExhaustiveRacecraft extends "res://game/ai/racecraft.gd":
	func coordinates(driver, vehicle: Node3D) -> Vector2:
		return preload("res://tools/validate_racecraft_projection.gd").original(driver,vehicle)

func _initialize() -> void:
	call_deferred("profile")

func profile() -> void:
	var results: Array = []
	var before := "--before" in OS.get_cmdline_user_args()
	var moving := "--moving" in OS.get_cmdline_user_args()
	for count in [4,8,12,15]:
		var main = load("res://game/main/main.tscn").instantiate()
		main.roster_seed = 1234
		root.add_child(main)
		main.process_mode = Node.PROCESS_MODE_DISABLED
		var fixture = load("res://tools/validate_racecraft.gd").new()
		var drivers: Array = []
		for i in range(count):
			var car = main.ai_cars[i]
			if before:
				var driver = car.get_node("Driver")
				driver.racecraft = ExhaustiveRacecraft.new()
				driver.racecraft.configure(JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/mile_oval/ai/racing_corridor.json")),driver.race)
			fixture.place(car,100+i*9,0,65)
			drivers.append(car.get_node("Driver"))
		var traffic_times: Array[float] = []
		var planning_times: Array[float] = []
		for tick in range(60):
			if moving:
				for driver in drivers:
					driver.car.global_position += driver.car.track.global_basis*Vector3(.7,0,0)
					driver._update_index(driver.car.track.to_local(driver.car.global_position))
			var start := Time.get_ticks_usec()
			for driver in drivers:
				driver.racecraft.update(driver,1.0/60)
			traffic_times.append((Time.get_ticks_usec()-start)/1000.0)
			start = Time.get_ticks_usec()
			for driver in drivers:
				driver._planned_speed()
			planning_times.append((Time.get_ticks_usec()-start)/1000.0)
		traffic_times.sort()
		planning_times.sort()
		var item := {"racing":count,"moving":moving,"traffic_median_ms":traffic_times[30],"traffic_p95_ms":traffic_times[57],"planning_median_ms":planning_times[30],"planning_p95_ms":planning_times[57]}
		results.append(item)
		print(JSON.stringify(item))
		fixture.free()
		main.free()
	var tag := ("moving_" if moving else "")+("before" if before else "after")
	var file := FileAccess.open("res://builds/racecraft_cpu_"+tag+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	file.close()
	quit()
