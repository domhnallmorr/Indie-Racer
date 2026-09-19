extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://game/main/main.tscn").instantiate()
	scene.ai_enabled = true
	root.add_child(scene)
	await process_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.get_node("HUD").hide()
	var stations = scene.get_node("MileOval/PitStations")
	assert(stations.stations.size() == 27)
	var station = stations.stations[0]
	for i in range(27):
		var item = stations.stations[i]
		assert(item.find_children("Engineer*","Sprite3D",true,false).size() == 3)
		assert(item.position.z+1.8 < 86.75)
		if i > 0:
			assert(item.position.x-stations.stations[i-1].position.x > 5.4)
	for car in scene.ai_cars:
		var matched := false
		for item in stations.stations:
			if item.get_meta("pit_box_id","") == car.player_state.assigned_pit_box_id:
				assert(item.red.albedo_color.is_equal_approx(Color.html(car.get_meta("roster_entry").colour)))
				matched = true
		assert(matched)
	assert(station.find_children("Engineer*","Sprite3D",true,false).size() == 3)
	assert(station.position.z+1.8 < 86.75)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.far = 2000
	camera.fov = 58
	camera.make_current()
	for view in [
		["pit_station_detail",Vector3(-6,3.0,6.4),Vector3(0,1.35,0)],
		["pit_station_approach",Vector3(-12,1.05,8.3),Vector3(0,1.5,0)],
		["pit_station_equipment",Vector3(-4,2,-4),Vector3(0,1.2,.4)],
		["pit_stations_overview",Vector3(-23,14,32),Vector3(100,0,0)],
		["pit_stations_lane",Vector3(0,1.1,14),Vector3(45,1.4,0)],
		["pit_station_variant",Vector3(5,3,6),Vector3(10,1.3,0)]]:
		camera.global_position = station.global_position+view[1]
		camera.look_at(station.global_position+view[2])
		for i in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/"+view[0]+".png")
	print("PIT STATIONS PASSED: 27 spaced stations, 81 crew cutouts, occupied colours match assigned cars; clear service apron.")
	quit()
