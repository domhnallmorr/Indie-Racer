extends SceneTree
## Compare broad-phase queries with the exhaustive corridor test, including edges.
func _initialize() -> void:
	var cached = load("res://game/race/track_session_data.gd").new()
	var reference = load("res://game/race/track_session_data.gd").new()
	assert(cached.load_config("res://content/tracks/mile_oval/session.json") == OK)
	assert(reference.load_config("res://content/tracks/mile_oval/session.json") == OK)
	reference.pit_sections.clear()
	var points: Array[Vector3] = []
	for p in cached.pit_path:
		for offset in [0.0,cached.half_width,-cached.half_width,cached.half_width+.001]:
			points.append(p+Vector3(offset,0,0))
			points.append(p+Vector3(0,0,offset))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in range(2000):
		points.append(Vector3(rng.randf_range(-400,400),rng.randf_range(-1,3),rng.randf_range(-160,160)))
	for point in points:
		assert(cached.contains_pit_lane(point) == reference.contains_pit_lane(point),"Lane mismatch at "+str(point))
		assert(cached.contains_speed_limit_zone(point) == reference.contains_speed_limit_zone(point),"Limiter mismatch at "+str(point))
	assert(cached.load_config("res://content/tracks/mile_oval/session.json") == OK)
	assert(cached.pit_sections.size() == ceili((cached.pit_path.size()-1)/20.0),"Reload must replace bounds")
	print("Pit queries PASS: ",points.size()," boundary/random positions; reload")
	quit()
