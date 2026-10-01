extends SceneTree
const Bank = preload("res://game/vehicle/engine_sound_bank.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)

func settle(audio: Node, frames := 30) -> void:
	for i in range(frames):
		audio._process(1.0/60.0)

func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		freeze(child)

func bank_checks() -> void:
	for key in Bank.SAMPLES:
		var sample := Bank.stream_for(key)
		check(sample.format == AudioStreamWAV.FORMAT_16_BITS and not sample.stereo, "Prepared PCM mono: "+key)
		check(sample.get_length() > 1.0 and sample.loop_end == sample.data.size()/2, "Full loop bounds: "+key)
		check(sample.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Loop enabled: "+key)
		check(Bank.stream_for(key) == sample, "Shared sample cache: "+key)
	for perspective in ["inside", "outside"]:
		for throttle in [0.0, 0.1, 0.15, 0.4, 0.7, 1.0]:
			var previous: Dictionary = {}
			for rpm in range(2000, 15001, 10):
				var mix := Bank.mix(perspective, rpm, throttle)
				var energy := 0.0
				for key in mix:
					var value: Vector2 = mix[key]
					energy += value.x*value.x
					check(is_finite(value.x) and value.x >= 0.0 and value.y > 0.0, "Finite mixer weights")
					if previous.has(key):
						check(absf(value.x-previous[key].x) < 0.04, "Continuous RPM blend: "+perspective)
				check(absf(energy-1.0) < 0.0001, "No holes or duplicate boosts: "+perspective)
				previous = mix
	check(is_equal_approx(Bank.mix("inside", 10100, 1.0)["internal_h5h"].y, 1.0), "Natural RPM gives original pitch")
	check(is_equal_approx(Bank.mix("outside", 7200, 1.0)["indy_onhigh_ex"].x, 1.0), "Repeated exterior sample merged")
	check(Bank.mix("inside", 13800, 0.0)["internal_oh1g"].x > 0.99, "High-RPM lift retains coast sound")

func driveby_checks(car: Node3D, audio: Node, camera: Camera3D) -> void:
	var saved_position := car.global_position
	var saved_camera := camera.global_transform
	camera.make_current()
	camera.global_position = Vector3(0, 2, 0)
	car.speed_mps = 90.0
	# Traverse a fixed TV viewpoint at constant RPM: pitch must fall on passage.
	var approach := 1.0
	var departure := 1.0
	for i in range(241):
		car.global_position = Vector3(-180.0+i*1.5, 0, -15)
		audio._physics_process(1.0/60.0)
		audio._process(1.0/60.0)
		if i == 60:
			approach = audio.doppler_pitch
		if i == 180:
			departure = audio.doppler_pitch
	check(approach > 1.25 and departure < 0.85, "TV pass raises approach pitch and lowers departure pitch")
	var voice: Dictionary = audio.voices["outside/indy_onhigh_ex"]
	check(is_equal_approx(voice.player.pitch_scale, audio.audible_rpm/voice.natural_rpm*audio.doppler_pitch), "Exterior playback receives combined RPM and Doppler pitch")
	check(voice.player.doppler_tracking == AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED, "No duplicate native Doppler")
	# Repeated render frames must not recalculate acceleration from a stale speed.
	car.speed_mps += 0.1
	car.position.x += 1.5
	audio._physics_process(1.0/60.0)
	var load_value: float = audio._engine_state(1.0/60.0).y
	for fps in [30, 60, 144, 240]:
		for i in range(5):
			audio._process(1.0/fps)
			check(is_equal_approx(audio._engine_state(1.0/fps).y, load_value), "AI load stays stable between physics ticks at different render rates")
	# Following at the same speed should cancel the shift after smoothing settles.
	for i in range(120):
		car.position.x += 1.5
		camera.global_position = car.global_position+Vector3(-10, 2, 0)
		audio._physics_process(1.0/60.0)
		audio._process(1.0/60.0)
	check(absf(audio.doppler_pitch-1.0) < 0.01, "Moving listener cancels shared source motion")
	camera.position.x += 300.0
	audio._process(1.0/60.0)
	check(audio.listener_velocity == Vector3.ZERO, "TV camera cut clears listener velocity")
	check(audio.doppler_pitch > 1.2 and audio.doppler_pitch < 1.5, "TV cut immediately uses new radial direction")
	car.global_position = saved_position
	car.speed_mps = 0.0
	audio._physics_process(1.0/60.0)
	check(audio.source_velocity == Vector3.ZERO, "Car reset clears source velocity")
	camera.global_transform = saved_camera
	print("TV drive-by Doppler: approach=%.3f departure=%.3f" % [approach, departure])

func validate() -> void:
	bank_checks()
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	freeze(main)
	var player_audio = main.player.get_node("EngineAudio")
	check(main.ai_cars.size() == 15, "Full field spawned")
	check(player_audio._engine_state(0.016).z == 0, "Parked player starts silent")
	settle(player_audio)
	check(player_audio.active_voice_count() == 0, "Stopped engine has no active voices")
	for car in main.ai_cars:
		var audio = car.get_node("EngineAudio")
		check(audio._engine_state(0.016).z == 0, "Parked AI starts silent")
		car.player_state.set_engine_running(true)
		check(audio._engine_state(0.016).z == 1, "Running AI audible without player controls")
		check(audio.voices.size() == 3, "AI allocates only three unique exterior voices")
		check(audio.voices["outside/indy_idle_ex"].player.stream == player_audio.voices["outside/indy_idle_ex"].player.stream, "Full field shares sample memory")
	var ai = main.ai_cars[0]
	var ai_audio = ai.get_node("EngineAudio")
	ai.speed_mps = 0
	var idle: Vector3 = ai_audio._engine_state(0.016)
	ai.speed_mps = 65
	var racing: Vector3 = ai_audio._engine_state(0.016)
	check(racing.x > idle.x and racing.y > idle.y, "Reference AI RPM/load respond to speed")
	check(racing.x <= ai.parameters.values.redline_rpm, "Reference AI respects redline")
	ai.speed_mps = 0
	check(is_equal_approx(ai_audio._engine_state(0.016).x, ai.parameters.values.idle_rpm), "Stopped running AI idles")
	main.player_state.set_engine_running(true)
	main.player.driving_enabled = true
	main.player.sim.engine_omega = 9000.0*TAU/60.0
	main.player.sim.throttle = 0.8
	check(is_equal_approx(player_audio._engine_state(0.016).x, 9000), "Player uses physical RPM")
	var cockpit = main.player.get_node("Cockpit")
	cockpit.activate()
	settle(player_audio)
	settle(ai_audio)
	check(player_audio.interior_mix == 1.0, "Cockpit selects own interior bank")
	check(player_audio.active_voice_count() > 0, "Interior samples playing")
	for voice: Dictionary in player_audio.voices.values():
		check(not voice.player.playing or voice.perspective == "inside", "Own exterior muted in cockpit")
	check(ai_audio.interior_mix == 0.0, "Opponents remain exterior in cockpit")
	check(root.audio_listener_enable_3d and root.get_audio_listener_3d() == null, "Main camera is listener")
	check(cockpit.camera.doppler_tracking != Camera3D.DOPPLER_TRACKING_DISABLED, "Moving cockpit listener tracks Doppler")
	for mirror in cockpit.mirror_views:
		check(not mirror.audio_listener_enable_3d, "Mirror listener disabled")
	var exterior = main.get_node("InspectionCamera")
	driveby_checks(ai, ai_audio, exterior)
	for key in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_6, KEY_7, KEY_T]:
		var event := InputEventKey.new()
		event.pressed = true
		event.keycode = key
		exterior._unhandled_input(event)
		settle(player_audio)
		check(root.get_camera_3d() == exterior and player_audio.interior_mix == 0.0, "Exterior mix follows view "+str(key))
		for voice: Dictionary in player_audio.voices.values():
			check(not voice.player.playing or voice.perspective == "outside", "Interior stops after camera switch")
	cockpit.activate()
	player_audio._process(1.0/60.0)
	check(player_audio.interior_mix > 0.0 and player_audio.interior_mix < 1.0, "Camera change crossfades")
	settle(player_audio)
	main.player.sim.shift_remaining = 0.1
	check(player_audio._engine_state(0.016).y == 0, "Shift cuts power sound")
	settle(player_audio)
	check(player_audio.voices["inside/internal_oh1g"].level > 0, "Shift uses recorded coast bank")
	main.player.sim.shift_remaining = 0.0
	main.player.sim.engine_omega = 13800.0*TAU/60.0
	main.player.sim.throttle = 0.0
	settle(player_audio)
	check(player_audio.active_voice_count() > 0, "Actual mixer stays audible at redline on lift")
	main.player_state.set_engine_running(false)
	settle(player_audio)
	check(player_audio.active_voice_count() == 0, "Shutdown stops all engine layers")
	main.player_state.set_engine_running(true)
	settle(player_audio)
	check(player_audio.active_voice_count() > 0, "Restart resumes engine layers")
	main.player.driving_enabled = false
	settle(player_audio)
	check(player_audio.active_voice_count() == 0, "Disabled player fades out")
	main.player.driving_enabled = true
	exterior.make_current()
	exterior.global_position = main.player.global_position+Vector3(2000,100,0)
	settle(player_audio)
	check(player_audio.active_voice_count() == 0, "Far camera culls all voices")
	exterior.global_position = main.player.global_position+Vector3(0,3,5)
	settle(player_audio)
	check(player_audio.active_voice_count() > 0, "Culled voices resume on approach")
	var field_voices := 0
	for car in main.ai_cars:
		settle(car.get_node("EngineAudio"))
		field_voices += car.get_node("EngineAudio").active_voice_count()
	check(field_voices <= 45 and field_voices > 0, "Bounded full-field exterior voices")
	print("Full field active exterior voices: ", field_voices, "; cached loops: ", Bank.loops.size())
	var bicycle = load("res://content/vehicles/open_wheel/scenes/player_vehicle.tscn").instantiate()
	bicycle.human_controlled = false
	root.add_child(bicycle)
	check(bicycle.get_node("EngineAudio")._engine_state(0.016).z == 1, "Bicycle AI audible without driving_enabled")
	bicycle.queue_free()
	main.queue_free()
	await process_frame
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("ENGINE AUDIO CHECK PASSED: samples, full RPM/load sweep, both AI models, camera blending, shift/lift, shutdown/restart and culling.")
	quit(0 if failures.is_empty() else 1)
