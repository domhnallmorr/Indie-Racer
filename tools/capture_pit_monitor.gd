extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1280,720)
	var main = load("res://game/main/main.tscn").instantiate()
	main.ai_enabled = false
	root.add_child(main)
	var monitor = main.get_node("PitMonitor")
	for frame in range(15):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/pit_monitor_cockpit.png")
	monitor.open()
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/pit_monitor_home.png")
	monitor._open_setup()
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/pit_monitor_setup.png")
	monitor._open_fuel()
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/pit_monitor_fuel.png")
	monitor._open_setup()
	monitor._open_wings()
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/pit_monitor_wings.png")
	print("MONITOR BOUNDS ",monitor.panel.get_global_rect()," VIEWPORT ",root.get_visible_rect())
	assert(root.get_visible_rect().encloses(monitor.panel.get_global_rect()))
	monitor.cockpit.deactivate()
	await process_frame
	await process_frame
	assert(not monitor.focused and not monitor.hardware.visible)
	main.session.start_qualifying()
	monitor.cockpit.activate()
	await process_frame
	await process_frame
	assert(monitor.available() and monitor.hardware.visible)
	monitor.open()
	main.get_node("HUD/RaceUI").open_page("session")
	await process_frame
	await process_frame
	assert(not monitor.focused and not monitor.hardware.visible)
	main.get_node("HUD/RaceUI").close_shell()
	main.session.advance(600)
	await process_frame
	await process_frame
	assert(monitor.depart.disabled)
	print("PIT MONITOR: captures, layout, camera switching, qualifying, F12 and session expiry passed.")
	quit()
