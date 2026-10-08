extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func v(p: Array) -> Vector3:
	return Vector3(p[0],p[1],p[2])

func validate() -> void:
	root.set_meta("roster_selection",{"track_id":"surfers_paradise","session_mode":"private_testing","ai_telemetry":false})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	for i in range(3): await physics_frame
	# Disabling the whole branch removes its collision bodies from physics.
	main.player.driving_enabled = false
	var track: Node3D = main.get_node("MileOval")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/surfers_paradise/geometry.json"))
	var space := root.world_3d.direct_space_state
	var excludes: Array[RID] = [main.player.get_rid()]
	check(data.patches.size()==4,"Two first-chicane and two backstraight grass islands")
	for patch in data.patches:
		var n: int = patch.points.size()/2
		for index in [n/3,n/2,n*2/3]:
			var at: Vector3 = (v(patch.points[index])+v(patch.points[2*n-1-index]))*.5
			var world := track.to_global(at)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(world+Vector3.UP,world-Vector3.UP,1,excludes))
			check(not hit.is_empty() and str(hit.collider.get_parent().name).begins_with(patch.name),"Grass collision follows visible island: "+str(patch.name))
			if not hit.is_empty(): check(hit.normal.y>.99 and absf(hit.position.y-.025)<.002,"Grass is a level, upward-facing surface")
			main.player.global_position = world+Vector3.UP*.03
			check(is_equal_approx(main.player._surface_grip(),main.player.parameters.values.grass_grip_multiplier),"Grass invokes existing reduced grip")
	var kerbs := 0
	for strip in data.strips:
		if strip.name in ["T1Kerb","BackstraightKerb"]:
			kerbs += 1
			if kerbs%10!=0: continue
			var at: Vector3 = (v(strip.rows[0][1])+v(strip.rows[1][2]))*.5
			var world := track.to_global(at)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(world+Vector3.UP,world-Vector3.UP,1,excludes))
			check(not hit.is_empty() and str(hit.collider.get_parent().name).begins_with(strip.name),"Kerb crown has physical collision: "+str(strip.name))
			if not hit.is_empty(): check(hit.normal.y>.99 and absf(hit.position.y-.06)<.003,"Low kerb crown height and normal")
			main.player.global_position = world+Vector3.UP*.03
			check(is_equal_approx(main.player._surface_grip(),1.0),"Kerb retains tarmac grip")
		if strip.name in ["BeachWall","CityWall"]:
			# Probe the displaced wall halfway through the revised street envelope.
			for index in [220,1440,1475,1520]:
				var row: Array = strip.rows[index if strip.name=="BeachWall" else index-165]
				var at := track.to_global(v(row[0])+Vector3.UP*.5)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at-Vector3(0,0,2),at+Vector3(0,0,2),1,excludes))
				check(not hit.is_empty() and str(hit.collider.get_parent().name).begins_with(strip.name),"Moved barrier retains collision: "+str(strip.name))
	check(kerbs>350,"Broad striped kerbs generated in both complexes")
	for patch_index in [0,2]:
		await check_crossing(main,track,data,patch_index)
	for failure in failures: push_error(failure)
	print("SURFERS LANDSCAPE ","PASS: grass collision/grip, physical kerb crossing and moved barrier collision in both chicanes" if failures.is_empty() else failures)
	main.free()
	quit(0 if failures.is_empty() else 1)

func check_crossing(main: Node, track: Node3D, data: Dictionary, patch_index: int) -> void:
	# Cross a real kerb from asphalt onto grass with the player's physics model.
	var kerb: Dictionary = {}
	var kerb_name := "T1Kerb" if patch_index==0 else "BackstraightKerb"
	for strip in data.strips:
		if strip.name==kerb_name and v(strip.rows[0][0]).distance_to(v(data.patches[patch_index].points[55]))<4:
			kerb = strip
			break
	check(not kerb.is_empty(),"Find representative apex kerb")
	if not kerb.is_empty():
		var inside := v(kerb.rows[0][0])
		var outward := (v(kerb.rows[0][-1])-inside).normalized()
		outward.y = 0
		outward = outward.normalized()
		main.player.global_position = track.to_global(inside-outward*1.0+Vector3.UP*.08)
		main.player.look_at(main.player.global_position+outward)
		main.player.reset_dynamics()
		main.player_state.pit_stall_state = main.player_state.StallState.NONE
		main.player_state.set_engine_running(true)
		main.player.sim.u = 6.0
		var from: Vector3 = main.player.global_position
		var wall_contacts := 0
		for tick in range(60):
			main.player.drive_step(1.0/60,.15,0,0)
			for i in range(main.player.get_slide_collision_count()):
				if absf(main.player.get_slide_collision(i).get_normal().y)<.5: wall_contacts += 1
			await physics_frame
		check((main.player.global_position-from).dot(outward)>3.0,"Car can drive over bevel onto grass")
		check(wall_contacts==0,"Kerb does not act as a vertical wall")
		check(main.player.surface_name=="grass","Car reaches reduced-grip grass after crossing")
