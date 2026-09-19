extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1280,720)
	var scene = load("res://game/main/main.tscn").instantiate()
	scene.ai_enabled = false
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	scene.get_node("HUD").hide()
	scene.player.get_node("Cockpit/VirtualMirrorOverlay").hide()
	await physics_frame
	await physics_frame
	var track = scene.get_node("MileOval")
	var access = track.get_node("PitAccess")
	var data = scene.track_data
	var line_z: float = access.get_node("LimiterEntryLine").position.z
	assert(not data.contains_speed_limit_zone(Vector3(access.entry_x-.5,0,line_z)))
	assert(data.contains_speed_limit_zone(Vector3(access.entry_x+.5,0,line_z)))
	assert(not data.contains_speed_limit_zone(Vector3(-170,0,110)))
	assert(not data.contains_speed_limit_zone(Vector3(-129,0,109)))
	assert(is_equal_approx(track.get_node("PitEntryProtection").wall_start_x,access.entry_x))
	var wall_ray := PhysicsRayQueryParameters3D.create(track.to_global(Vector3(-110,.5,106)),track.to_global(Vector3(-110,.5,110)))
	assert(not track.get_world_3d().direct_space_state.intersect_ray(wall_ray).is_empty())
	for point in [Vector3(-115,.025,96),Vector3(-106,.025,93),Vector3(-94,.025,93)]:
		assert(data.contains_pit_lane(point) and data.contains_speed_limit_zone(point))
		scene.player.global_position = track.to_global(point)
		assert(scene.player._surface_grip() == 1.0 and scene.player.surface_name == "tarmac")
		var ray := PhysicsRayQueryParameters3D.create(track.to_global(point+Vector3.UP),track.to_global(point-Vector3.UP))
		ray.exclude = [scene.player.get_rid()]
		var hit: Dictionary = track.get_world_3d().direct_space_state.intersect_ray(ray)
		assert(not hit.is_empty() and hit.normal.dot(Vector3.UP) > .99)
		assert(absf(track.to_local(hit.position).y-.004) < .002)
	scene.player.global_transform = track.global_transform*data.pit_box_transform()
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		scene.add_child(camera)
		camera.far = 2000
		camera.fov = 55
		camera.make_current()
		for view in [
			["pit_limiter_entry",Vector3(-153,5,105),Vector3(-123,0,104)],
			["pit_entry_wall",Vector3(-163,30,90),Vector3(-109,0,106)],
			["pit_box_approach",Vector3(-130,23,125),Vector3(-99,0,94)],
		]:
			camera.position = track.to_global(view[1])
			camera.look_at(track.to_global(view[2]))
			for frame in range(10):
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://builds/%s.png" % view[0])
	print("PIT ACCESS PASSED: limiter line straddles activation boundary; approach has level asphalt collision, grip and pit detection.")
	quit()
