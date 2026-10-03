extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

# Independent original exhaustive implementation, kept only as a test oracle.
static func original(driver, vehicle: Node3D) -> Vector2:
	var p: Vector3 = driver.car.track.to_local(vehicle.global_position)
	var other_driver = vehicle.get_node_or_null("Driver")
	var hint: int = other_driver.index if other_driver != null and other_driver.mode == 2 else driver.index
	var best := INF
	var result := Vector2.ZERO
	var search_all: bool = other_driver == null or other_driver.mode != 2
	for step in range(driver.race.size() if search_all else 7):
		var i: int = step if search_all else posmod(hint+step-3,driver.race.size())
		var next: int = (i+1)%driver.race.size()
		var a := Vector2(driver.race[i].x,driver.race[i].z)
		var b := Vector2(driver.race[next].x,driver.race[next].z)
		var point := Vector2(p.x,p.z)
		var t := clampf((point-a).dot(b-a)/maxf(a.distance_squared_to(b),.001),0,1)
		var error := point.distance_squared_to(a.lerp(b,t))
		if error < best:
			best = error
			var low: Vector3 = driver.racecraft.inner[i].lerp(driver.racecraft.inner[next],t)
			var high: Vector3 = driver.racecraft.outer[i].lerp(driver.racecraft.outer[next],t)
			var outward := Vector2(high.x-low.x,high.z-low.z).normalized()
			result = Vector2(lerpf(driver.race_distances[i],driver.race_distances[i+1],t),(point-Vector2(low.x,low.z)).dot(outward)-8.0)
	return result

func compare(driver, vehicle: Node3D) -> void:
	var expected := original(driver,vehicle)
	for repeat in range(2):
		var actual: Vector2 = driver.racecraft.coordinates(driver,vehicle)
		if actual.distance_to(expected) > .001:
			failures.append("Projection mismatch at %s: %s vs %s" % [vehicle.global_position,actual,expected])

func validate() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_seed = 1234
	root.add_child(main)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var driver = main.ai_cars[0].get_node("Driver")
	for vehicle in [main.player]+main.ai_cars:
		compare(driver,vehicle)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4421
	for i in range(1000):
		main.player.global_position = driver.car.track.to_global(Vector3(rng.randf_range(-450,450),rng.randf_range(-1,4),rng.randf_range(-200,200)))
		compare(driver,main.player)
	# Every vertex, segment boundary, and lap seam; also exercise racing hints.
	var other = main.ai_cars[1]
	var other_driver = other.get_node("Driver")
	# Observers share the configured corridor, but cars can move and change
	# their index/mode between two observers' queries in the same physics tick.
	driver.racecraft.projection_cache["shared_probe"] = true
	if not other_driver.racecraft.projection_cache.has("shared_probe"):
		failures.append("Session drivers did not share their projection cache")
	driver.racecraft.projection_cache.erase("shared_probe")
	for i in range(120):
		other_driver.index = (i*17)%driver.race.size()
		other_driver.mode = 2 if i%2 == 0 else 1
		other.global_position = driver.car.track.to_global(driver.race[other_driver.index]+Vector3(1,0,2))
		compare(driver,other)
		compare(other_driver,other)
		other.global_position += Vector3(.4,0,-.3)
		compare(other_driver,other)
		compare(driver,other)
	for i in range(driver.race.size()):
		main.player.global_position = driver.car.track.to_global(driver.race[i])
		compare(driver,main.player)
		other.global_position = main.player.global_position
		other_driver.mode = 2
		other_driver.index = i
		compare(driver,other)
		other_driver.mode = 1
		compare(driver,other)
	# Reconfiguration must invalidate old results and rebuild spatial bounds.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/mile_oval/ai/racing_corridor.json"))
	driver.racecraft.configure(data,driver.race)
	if not driver.racecraft.projection_cache.is_empty():
		failures.append("Reconfigure retained cached vehicle coordinates")
	other_driver.racecraft.projection_cache["shared_probe"] = true
	if driver.racecraft.projection_cache.has("shared_probe"):
		failures.append("Reconfigure did not detach from the old corridor cache")
	other_driver.racecraft.projection_cache.erase("shared_probe")
	compare(driver,other)
	for failure in failures.slice(0,5):
		push_error(failure)
	print("PROJECTION PASSED: exhaustive equivalence, moving/player/pit/racing queries, vertices, seam, cache hits, reconfiguration" if failures.is_empty() else "PROJECTION FAILED: "+str(failures.size()))
	main.free()
	quit(0 if failures.is_empty() else 1)
