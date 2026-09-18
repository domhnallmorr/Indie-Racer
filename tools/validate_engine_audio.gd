extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func validate() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var player_audio = main.player.get_node("EngineAudio")
	check(player_audio is AudioStreamPlayer3D, "Player has spatial engine audio")
	check(main.ai_cars.size() > 0, "AI field spawned")
	for car in main.ai_cars:
		var engine = car.get_node("EngineAudio")
		check(engine is AudioStreamPlayer3D and engine.playing, "AI engine playing: "+str(car.name))
		check(engine.stream == player_audio.stream, "Field reuses one synthesized loop")
		check(engine._engine_state(0.016).z == 1, "AI audible despite disabled player controls")
	var ai = main.ai_cars[0]
	var ai_audio = ai.get_node("EngineAudio")
	ai.speed_mps = 0
	var idle: Vector3 = ai_audio._engine_state(0.016)
	ai.speed_mps = 65
	var racing: Vector3 = ai_audio._engine_state(0.016)
	check(racing.x > idle.x and racing.y > idle.y, "Reference AI pitch/load respond to speed")
	check(racing.x <= ai.parameters.values.redline_rpm, "AI RPM bounded by engine config")
	ai.speed_mps = 0
	check(is_equal_approx(ai_audio._engine_state(0.016).x, ai.parameters.values.idle_rpm), "Stopped AI returns to idle")
	var cockpit = main.player.get_node("Cockpit")
	cockpit.activate()
	check(root.get_camera_3d() == cockpit.camera, "Cockpit is active listening camera")
	check(root.audio_listener_enable_3d and root.get_audio_listener_3d() == null, "Root listens from active camera")
	for mirror in cockpit.mirror_views:
		check(not mirror.audio_listener_enable_3d, "Mirrors do not add listeners")
	var exterior = main.get_node("InspectionCamera")
	for key in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_6, KEY_7]:
		var event := InputEventKey.new()
		event.pressed = true
		event.keycode = key
		exterior._unhandled_input(event)
		check(root.get_camera_3d() == exterior, "Exterior camera/listener switch "+str(key))
	cockpit.activate()
	check(root.get_camera_3d() == cockpit.camera, "Listener returns to cockpit")
	main.player.sim.engine_omega = 9000.0 * TAU / 60.0
	main.player.sim.throttle = 0.8
	check(is_equal_approx(player_audio._engine_state(0.016).x, 9000), "Player uses real RPM")
	main.player.sim.shift_remaining = 0.1
	check(player_audio._engine_state(0.016).y == 0, "Shifting cuts engine load")
	main.player.driving_enabled = false
	check(player_audio._engine_state(0.016).z == 0, "Disabled player fades out")
	main.player.driving_enabled = true
	# Exercise alternate bicycle AI with the shared vehicle scene, too.
	var bicycle = load("res://content/vehicles/open_wheel/scenes/player_vehicle.tscn").instantiate()
	bicycle.human_controlled = false
	root.add_child(bicycle)
	check(bicycle.get_node("EngineAudio")._engine_state(0.016).z == 1, "Bicycle AI audible without driving_enabled")
	bicycle.queue_free()
	for i in range(30):
		await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("ENGINE AUDIO CHECK PASSED: full field, both AI models, RPM/load, idle, shifting, camera switches and mirror isolation.")
	quit(0 if failures.is_empty() else 1)
