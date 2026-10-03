extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message)
func run() -> void:
	root.set_meta("roster_selection",{"track_id":"texas","session_mode":"race","file":"res://content/rosters/irl_2001/manifest.json","seed":42})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	var track: Node3D = main.get_node("MileOval")
	var excluded: Array[RID] = []
	for car in [main.player]+main.ai_cars: excluded.append(car.get_rid())
	await physics_frame
	# Check all supported grid slots, including the two different lane heights.
	var minimum := INF
	for slot in range(26):
		var pose: Transform3D = track.global_transform*main.track_data.grid_transform(slot)
		for x in [-.925,.925]:
			for z in [-2.115,2.235]:
				var p := pose*Vector3(x,0,z)
				var query := PhysicsRayQueryParameters3D.create(p+Vector3.UP*5,p-Vector3.UP*5,1)
				query.exclude = excluded
				var hit := root.world_3d.direct_space_state.intersect_ray(query)
				check(not hit.is_empty(),"Grid slot %d missing surface" % slot)
				if hit.is_empty(): continue
				minimum = minf(minimum,p.y-hit.position.y)
				check(p.y >= hit.position.y,"Grid slot %d chassis below road" % slot)
	for i in range(90): await physics_frame
	var worst := 0.0
	for car in [main.player]+main.ai_cars:
		var visual: Node3D = car.get_node("Visual")
		for contact in visual.get_meta("tyre_contacts"):
			var p: Vector3 = visual.to_global(contact)
			var query := PhysicsRayQueryParameters3D.create(p+Vector3.UP*3,p-Vector3.UP*3,1)
			query.exclude = excluded
			var hit := root.world_3d.direct_space_state.intersect_ray(query)
			check(not hit.is_empty(),"Missing tyre support")
			if hit.is_empty(): continue
			worst = maxf(worst,absf(p.y-hit.position.y))
			check(absf(p.y-hit.position.y)<.06,"Tyre not grounded: %s gap %.3f" % [car.name,p.y-hit.position.y])
	# Tracks without generated road data retain their authored grid coordinates.
	var legacy = load("res://game/race/track_session_data.gd").new()
	check(legacy.load_config("res://content/tracks/mile_oval/session.json")==OK,"Mile Oval config")
	check(is_equal_approx(legacy.grid_transform(0).origin.y,legacy.grid_origin.y),"Mile Oval grid unchanged")
	print("GRID GROUNDING: 26 slots; minimum chassis clearance=",minimum,"; max tyre gap=",worst,"; failures=",failures)
	main.free()
	quit(0 if failures.is_empty() else 1)
