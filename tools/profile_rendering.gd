extends SceneTree
## Frozen rendering comparison followed by a live 15-car run at normal 60 Hz.
## --uncached-pits disables pit broad-phase bounds for a comparison run.
## Frame times include CPU submission; these are not isolated GPU timer queries.
var main
var camera: Camera3D
var results: Array = []
func _initialize() -> void:
	call_deferred("profile")

func sample(label: String) -> void:
	for i in range(20):
		await process_frame
	var times: Array[float] = []
	var calls := 0.0
	var primitives := 0.0
	var physics_ms := 0.0
	var last := Time.get_ticks_usec()
	for i in range(100):
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now-last)/1000.0)
		last = now
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
	times.sort()
	# The engine monitor updates periodically; it can retain startup cost while
	# the frozen cases run. Only report it after the live warm-up.
	var item := {"case":label,"median_frame_ms":times[50],"p95_frame_ms":times[95],"draw_calls":calls/100,"primitives":primitives/100,"physics_ms":physics_ms/100 if label.begins_with("live_") else null}
	results.append(item)
	print(JSON.stringify(item))

func profile() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	main = load("res://game/main/main.tscn").instantiate()
	main.roster_seed = 1234
	root.add_child(main)
	if "--uncached-pits" in OS.get_cmdline_user_args():
		main.track_data.pit_sections.clear()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var cockpit = main.get_node("DisplayCar/Cockpit")
	cockpit.deactivate()
	camera = main.get_node("InspectionCamera")
	camera.make_current()
	var line: PackedVector3Array = main.ai_cars[0].get_node("Driver").race
	for i in range(main.ai_cars.size()):
		var car = main.ai_cars[i]
		var idx := (i*12+100)%line.size()
		car.global_position = car.track.to_global(line[idx])+Vector3.UP*.1
		var direction: Vector3 = line[(idx+1)%line.size()]-line[idx]
		car.rotation.y = atan2(-direction.x,-direction.z)
	var target: Vector3 = main.get_node("MileOval").to_global(line[155])
	camera.global_position = target+Vector3(-20,8,14)
	camera.look_at(target)
	var pose := camera.global_transform
	await sample("external_full_scene")
	camera.look_at(camera.global_position+Vector3(0,-10,-.1))
	await sample("external_grass")
	camera.global_transform = pose
	main.get_node("Sun").shadow_enabled = false
	await sample("external_no_shadows")
	main.get_node("Sun").shadow_enabled = true
	var meshes: Array = main.get_node("MileOval").find_children("*","MeshInstance3D",true,false)
	print("Track mesh instances: ",meshes.size())
	for car in main.ai_cars:
		car.get_node("Visual").hide()
	await sample("external_no_ai_visuals")
	for car in main.ai_cars:
		car.get_node("Visual").show()
	cockpit.activate()
	for i in range(cockpit.rear_cameras.size()):
		cockpit.rear_cameras[i].global_transform = cockpit.global_transform*cockpit.rear_local_poses[i]
	await sample("cockpit_mirrors")
	for mirror in cockpit.mirror_views:
		mirror.render_target_update_mode = SubViewport.UPDATE_DISABLED
	await sample("cockpit_no_mirrors")
	cockpit.deactivate()
	camera.make_current()
	camera.follow_player = false
	camera.global_transform = pose
	for i in range(main.ai_cars.size()):
		var car = main.ai_cars[i]
		var driver = car.get_node("Driver")
		var idx: int = i*line.size()/main.ai_cars.size()
		driver.index = idx
		driver.mode = driver.Mode.RACING
		car.global_position = car.track.to_global(line[idx])+Vector3.UP*.1
		var direction: Vector3 = line[(idx+1)%line.size()]-line[idx]
		car.rotation.y = atan2(-direction.x,-direction.z)
		car.sim.u = 65.0
		car.speed_mps = 65.0
		car.sim.gear = 5
		car.sim.front_omega = 65/car.parameters.values.front_radius_m
		car.sim.rear_omega = 65/car.parameters.values.rear_radius_m
		car.sim.engine_omega = car.sim.rear_omega*car.sim.ratio()
	main.process_mode = Node.PROCESS_MODE_INHERIT
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	for i in range(180):
		await process_frame
	await sample("live_external")
	camera.look_at(camera.global_position+Vector3(0,-10,-.1))
	await sample("live_grass")
	camera.global_transform = pose
	main.get_node("Sun").shadow_enabled = false
	await sample("live_no_shadows")
	DirAccess.make_dir_recursive_absolute("res://builds")
	var suffix := "_uncached" if "--uncached-pits" in OS.get_cmdline_user_args() else ""
	var output := FileAccess.open("res://builds/render_profile"+suffix+".json",FileAccess.WRITE)
	output.store_string(JSON.stringify(results,"  "))
	output.close()
	quit()
