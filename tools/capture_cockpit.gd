extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.set_meta("roster_selection", {"session_mode":"private_testing","seed":1234,"ai_telemetry":false})
	var preview = load("res://game/main/main.tscn").instantiate()
	# Keep capture logs inside the project, independent of local user-data access.
	DirAccess.make_dir_recursive_absolute("res://builds")
	DirAccess.make_dir_recursive_absolute("res://tmp/cockpit_capture")
	preview.get_node("DisplayCar").telemetry.file = FileAccess.open("res://tmp/cockpit_capture/telemetry.csv",FileAccess.WRITE)
	root.add_child(preview)
	preview.get_node("HUD/FPSCounter").diagnostics_directory = "res://tmp/cockpit_capture"
	for i in range(12):
		await process_frame
	await frame("cockpit_pit")
	var cockpit = preview.get_node("DisplayCar/Cockpit")
	var inspection = preview.get_node("InspectionCamera")
	var player = preview.player
	var dashboard = cockpit.dashboard_view.get_child(0)
	var ui = preview.get_node("HUD/RaceUI")
	var toggle := InputEventKey.new()
	toggle.keycode = KEY_H
	toggle.pressed = true
	ui._unhandled_input(toggle)
	assert(not preview.get_node("HUD/BlackBox").visible)
	ui.open_page("timing")
	ui.close_shell()
	assert(not preview.get_node("HUD/BlackBox").visible)
	ui._unhandled_input(toggle)
	assert(preview.get_node("HUD/BlackBox").visible)
	assert(cockpit.camera.current)
	assert(cockpit.mirror_views.size() == 1)
	assert(cockpit.virtual_mirror.visible)
	assert(cockpit.virtual_mirror.get_child(0).flip_h)
	assert(cockpit.gear_lever != null)
	for item in cockpit.interior.find_children("*","MeshInstance3D",true,false):
		assert(not "Steering" in item.name)
	for key in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		cockpit._unhandled_input(event)
		inspection._unhandled_input(event)
		assert(cockpit.camera.current == (key == KEY_5))
		assert(inspection.current == (key != KEY_5))
		assert(cockpit.virtual_mirror.visible == (key == KEY_5))
		for mirror in cockpit.mirror_views:
			assert(mirror.render_target_update_mode == (SubViewport.UPDATE_ALWAYS if key == KEY_5 else SubViewport.UPDATE_DISABLED))
	# Freeze a real scene for repeatable on-track art captures and telemetry checks.
	preview.process_mode = Node.PROCESS_MODE_DISABLED
	cockpit.process_mode = Node.PROCESS_MODE_ALWAYS
	preview.get_node("HUD").hide()
	preview.get_node("PitMonitor").hardware.hide()
	player.global_transform = preview.get_node("MileOval").global_transform*Transform3D(Basis(Vector3.UP,-PI*.5),Vector3(-60,.025,129))
	player.get_node("Visual").transform = Transform3D.IDENTITY
	for i in range(30):
		player._update_visual_grounding(1.0/60)
	player.speed_mps = 82.5
	player.sim.u = 82.5
	player.sim.gear = 5
	player.sim.engine_omega = 12600*player.sim.RPM_TO_RAD
	player.player_state.engine_running = true
	player.player_state.is_in_pit_speed_zone = false
	player.player_state.pit_stall_state = player.player_state.StallState.NONE
	player.player_state.fuel_gal = 21.5
	preview.lap_timing.clock = 100.0
	var entry: Dictionary = preview.lap_timing.entries[0]
	entry.armed = true
	entry.laps = 3
	entry.started = 86.522
	entry.last = 29.471
	entry.best = 29.125
	var data: Dictionary = dashboard.sample_readouts()
	assert(data.speed == 297 and data.gear == "5" and data.lap == "4")
	assert(data.current == "0:13.478" and data.last == "0:29.471" and data.best == "0:29.125")
	assert(is_equal_approx(data.fuel,21.5*3.785411784))
	assert(data.session == "PRIVATE TESTING")
	# Accepted shifts animate; the lever returns to its neutral pose.
	cockpit.set_process(false)
	cockpit.last_gear = "5"
	player.sim.shift_remaining = 0.0
	assert(player.sim.select_gear(6))
	cockpit._process(.06)
	assert(absf(cockpit.gear_lever.rotation.x) > .01)
	cockpit._process(.30)
	assert(is_zero_approx(cockpit.gear_lever.rotation.x))
	player.sim.gear = 5
	cockpit.last_gear = "5"
	cockpit._process(0)
	await frame("cockpit_godot")
	cockpit.dashboard_view.get_texture().get_image().save_png("res://builds/cockpit_lcd.png")
	# The screen's corners must stay in view at the default FOV and seat height.
	var screen: MeshInstance3D = cockpit.get_node("Dashboard")
	var corners: PackedVector3Array = screen.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for height in [.76,.80,.84]:
		cockpit.camera.position.y = height
		for corner in corners:
			var projected: Vector2 = cockpit.camera.unproject_position(screen.to_global(corner))
			assert(root.get_visible_rect().has_point(projected),"LCD cropped at seat height %.2f" % height)
		await frame("cockpit_seat_%d" % int(height*100))
	cockpit.camera.position.y = .80
	# Check service and out-lap states without inventing engine sensor readings.
	entry.armed = false
	assert(dashboard.sample_readouts().current == "--:--.---")
	player.player_state.pit_stall_state = player.player_state.StallState.SERVICING
	player.player_state.service_remaining = 7.5
	assert(dashboard.sample_readouts().servicing)
	await frame("cockpit_service")
	player.player_state.pit_stall_state = player.player_state.StallState.NONE
	entry.armed = true
	preview.session.start_race(4)
	assert(dashboard.sample_readouts().lap == "--")
	preview.session.show_green()
	entry.laps = 4
	preview.session.finish_race()
	assert(dashboard.sample_readouts().lap == "4")
	assert(dashboard.sample_readouts().current == "0:29.471")
	preview.session.start_private_testing()
	entry.laps = 3
	# Keyboard reset retains the new default and the existing FOV control.
	var reset := InputEventKey.new()
	reset.keycode = KEY_HOME
	reset.pressed = true
	cockpit.camera.position.y = .90
	cockpit.camera.fov = 75
	cockpit._unhandled_input(reset)
	assert(is_equal_approx(cockpit.camera.position.y,.80) and is_equal_approx(cockpit.camera.fov,65))
	# Smaller and taller windows must keep the default LCD inside the viewport.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	for size in [Vector2i(1280,720),Vector2i(1200,900)]:
		DisplayServer.window_set_size(size)
		await frame("cockpit_%dx%d" % [size.x,size.y])
		for corner in corners:
			assert(root.get_visible_rect().has_point(cockpit.camera.unproject_position(screen.to_global(corner))),"LCD cropped at "+str(size))
	print("COCKPIT CHECK PASSED: rendered pit/track/service, dash fit, live timing/fuel, lever shift, wheel-free mesh, five cameras and mirror states.")
	quit()

func frame(label: String) -> void:
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://builds/"+label+".png") == OK)
