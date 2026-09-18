extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://game/main/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.get_node("HUD").hide()
	var track = scene.get_node("MileOval")
	var trucks = track.get_node("TeamTransporters")
	assert(trucks.placements.size() == 26)
	assert(trucks.get_node("TeamTransporters").multimesh.instance_count == 26)
	# Full footprint of each truck must fit the paved lot, without overlapping.
	for i in range(trucks.placements.size()):
		var p: Vector3 = trucks.placements[i].origin
		assert(p.x-1.6 > -196 and p.x+1.6 < 120)
		assert(p.z-10.6 > 16 and p.z+10.6 < 76)
		assert(p.x < -35 or p.x > 76,"Truck overlaps building/walkway")
		for j in range(i):
			var other: Vector3 = trucks.placements[j].origin
			assert(absf(p.x-other.x)>3.2 or absf(p.z-other.z)>21.2)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.far = 2000.0
	camera.near = .1
	camera.fov = 55.0
	camera.make_current()
	var views := [
		["transporters_overview",Vector3(-210,95,161),Vector3(-65,0,45)],
		["transporters_detail",Vector3(-151,6,47),Vector3(-158,2,63)],
		["transporters_east",Vector3(146,24,91),Vector3(99,1,48)],
	]
	for view in views:
		camera.position = track.global_position+view[1]
		camera.look_at(track.global_position+view[2])
		for i in range(16):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/%s.png" % view[0])
	print("TRANSPORTER CHECK PASSED: 26 shared-model trucks, paved-lot clearance and no overlaps. Captures complete.")
	quit()
