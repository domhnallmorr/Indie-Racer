extends Node3D
## Sampled V8 mixer. Only the viewed car uses cockpit audio; opponents stay spatial.
@export_range(-40.0, 0.0) var engine_volume_db := -12.0
const Bank = preload("res://game/vehicle/engine_sound_bank.gd")
const AUDIO_BUS := "Engines"
const MAX_DISTANCE := 650.0
const SILENCE := 0.0001
const SPEED_OF_SOUND := 343.0
const MOTION_SMOOTHING := 0.06
var vehicle: Node
var cockpit: Node
var audible_rpm := 2500.0
var audible_load := 0.0
var gain := 0.0
var interior_mix := 0.0
var audio_gear := 0
var previous_speed := 0.0
var acceleration := 0.0
var motion_ready := false
var previous_position := Vector3.ZERO
var source_velocity := Vector3.ZERO
var listener_camera: Camera3D
var listener_position := Vector3.ZERO
var listener_velocity := Vector3.ZERO
var doppler_pitch := 1.0
var voices: Dictionary = {}

func _ready() -> void:
	vehicle = get_parent()
	cockpit = vehicle.get_node_or_null("Cockpit")
	position = Vector3(0, 0.5, 0.8)
	# Sample motion after drivers, and mix after the active camera has moved.
	process_physics_priority = 100
	process_priority = 100
	_ensure_bus()
	_add_perspective("outside")

static func _ensure_bus() -> void:
	if AudioServer.get_bus_index(AUDIO_BUS) >= 0:
		return
	var index := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(index, AUDIO_BUS)
	AudioServer.set_bus_send(index, "Master")
	# Leave headroom for a full grid and catch unusually coherent close sources.
	var limiter := AudioEffectLimiter.new()
	limiter.threshold_db = -3.0
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(index, limiter)

func _add_perspective(perspective: String) -> void:
	for mode in ["power", "coast"]:
		for row: Array in Bank.BANKS[perspective + "_" + mode]:
			var id: String = perspective + "/" + row[0]
			if voices.has(id):
				continue
			var player: Node
			if perspective == "inside":
				player = AudioStreamPlayer.new()
			else:
				var spatial := AudioStreamPlayer3D.new()
				spatial.unit_size = 12.0
				spatial.max_distance = MAX_DISTANCE
				spatial.max_db = engine_volume_db
				spatial.attenuation_filter_cutoff_hz = 8500.0
				# Apply Doppler together with RPM, so render-frame pitch assignments
				# cannot overwrite a separate physics-frame Doppler adjustment.
				spatial.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
				player = spatial
			player.name = perspective + "_" + row[0]
			player.stream = Bank.stream_for(row[0])
			player.bus = AUDIO_BUS
			player.volume_db = -80.0
			add_child(player)
			var phase := float(posmod(get_instance_id() + id.hash(), 10007)) / 10007.0
			voices[id] = {"player": player, "level": 0.0,
				"phase": phase * player.stream.get_length(), "natural_rpm": float(row[3]),
				"perspective": perspective, "key": row[0]}

func _is_cockpit_camera(camera: Camera3D) -> bool:
	return is_instance_valid(cockpit) and camera != null and camera == cockpit.camera

func _physics_process(delta: float) -> void:
	var speed := absf(float(vehicle.speed_mps))
	var displacement := global_position - previous_position
	if motion_ready and displacement.length() < maxf(25.0, delta*200.0):
		var blend := 1.0-exp(-delta/MOTION_SMOOTHING)
		source_velocity = source_velocity.lerp(displacement/maxf(delta, 0.001), blend)
		acceleration = lerpf(acceleration, (speed-previous_speed)/maxf(delta, 0.001), blend)
	else:
		source_velocity = Vector3.ZERO
		acceleration = 0.0
		motion_ready = true
	previous_position = global_position
	previous_speed = speed

static func doppler_ratio(offset: Vector3, source: Vector3, listener: Vector3) -> float:
	# Offset points from listener to source. Approaching sources raise pitch;
	# a listener travelling alongside the source hears no shift.
	if offset.length_squared() < 0.01:
		return 1.0
	var direction := offset.normalized()
	var source_radial := clampf(source.dot(direction), -200.0, 200.0)
	var listener_radial := clampf(listener.dot(direction), -200.0, 200.0)
	return clampf((SPEED_OF_SOUND+listener_radial)/(SPEED_OF_SOUND+source_radial), 0.5, 2.0)

func _update_doppler(camera: Camera3D, delta: float) -> void:
	if camera == null:
		listener_camera = null
		listener_velocity = Vector3.ZERO
		doppler_pitch = 1.0
		return
	var displacement := camera.global_position-listener_position
	var cut := camera != listener_camera or displacement.length() > maxf(25.0, delta*200.0)
	if cut:
		listener_velocity = Vector3.ZERO
	else:
		listener_velocity = listener_velocity.lerp(displacement/maxf(delta, 0.001), 1.0-exp(-delta/MOTION_SMOOTHING))
	listener_camera = camera
	listener_position = camera.global_position
	var target := doppler_ratio(global_position-listener_position, source_velocity, listener_velocity)
	# Camera cuts immediately use the new viewpoint, without a false velocity.
	doppler_pitch = target if cut else lerpf(doppler_pitch, target, 1.0-exp(-delta/0.025))

func _process(delta: float) -> void:
	var state := _engine_state(delta)
	# Preserve pitch while the engine fades out rather than diving toward zero.
	if state.z > 0.0:
		audible_rpm = lerpf(audible_rpm, state.x, 1.0-exp(-delta/0.025))
	audible_load = lerpf(audible_load, state.y, 1.0-exp(-delta/0.025))
	gain = move_toward(gain, state.z, delta/0.10)
	var camera := get_viewport().get_camera_3d()
	_update_doppler(camera, delta)
	var inside := _is_cockpit_camera(camera)
	interior_mix = move_toward(interior_mix, 1.0 if inside else 0.0, delta/0.18)
	if inside and not voices.has("inside/internal_v1h"):
		_add_perspective("inside")
	var distance_gain := 0.0
	if camera != null:
		var distance := camera.global_position.distance_to(global_position)
		distance_gain = 1.0-smoothstep(MAX_DISTANCE-100.0, MAX_DISTANCE, distance)
	var revs := clampf((audible_rpm-2500.0)/11300.0, 0.0, 1.0)
	var loudness := gain * lerpf(0.55, 1.0, audible_load) * lerpf(0.85, 1.0, revs)
	var exterior := Bank.mix("outside", audible_rpm, audible_load)
	var interior := Bank.mix("inside", audible_rpm, audible_load) if interior_mix > 0.0 else {}
	for id in voices:
		var voice: Dictionary = voices[id]
		var onboard: bool = voice.perspective == "inside"
		var weights: Dictionary = interior if onboard else exterior
		var weight: Vector2 = weights.get(voice.key, Vector2.ZERO)
		var view_gain := sqrt(interior_mix) if onboard else sqrt(1.0-interior_mix)*distance_gain
		var target := weight.x * loudness * view_gain
		# A short release keeps layer culling and camera cuts from clicking.
		voice.level = move_toward(float(voice.level), target, delta/0.025)
		var player: Node = voice.player
		var motion_pitch := 1.0 if onboard else doppler_pitch
		player.pitch_scale = clampf(audible_rpm / float(voice.natural_rpm) * motion_pitch, 0.1, 4.0)
		voice.phase = fmod(float(voice.phase) + delta*player.pitch_scale, player.stream.get_length())
		if float(voice.level) > SILENCE:
			player.volume_db = engine_volume_db + linear_to_db(float(voice.level))
			if not onboard:
				# Clamp distance amplification, not the individual blend weights.
				player.max_db = player.volume_db
			if not player.playing:
				player.play(voice.phase)
		elif player.playing:
			player.stop()

func active_voice_count() -> int:
	var count := 0
	for voice: Dictionary in voices.values():
		if voice.player.playing:
			count += 1
	return count

func _engine_state(_delta: float) -> Vector3:
	if vehicle.player_state != null and not vehicle.player_state.engine_running:
		return Vector3.ZERO
	if not "physics_ready" in vehicle or not vehicle.physics_ready:
		return Vector3(2500, 0, 0)
	# AI is driven by its Driver node, not the player's driving_enabled flag.
	if vehicle.human_controlled and not vehicle.driving_enabled:
		return Vector3(2500, 0, 0)
	if "sim" in vehicle:
		return Vector3(vehicle.engine_rpm, vehicle.sim.throttle if vehicle.sim.shift_remaining <= 0 else 0.0, 1)
	# Reference AI has no drivetrain simulation. Estimate sound only from speed,
	# configured ratios and acceleration, without changing its driving physics.
	var p: Dictionary = vehicle.parameters.values
	var speed := absf(float(vehicle.speed_mps))
	var wheel_rpm := speed / (TAU * float(p.rear_radius_m)) * 60.0
	var ratios: Array = p.forward_ratios
	audio_gear = clampi(audio_gear, 0, ratios.size()-1)
	while audio_gear < ratios.size()-1 and wheel_rpm*float(ratios[audio_gear])*float(p.final_drive) > float(p.automatic_upshift_rpm):
		audio_gear += 1
	while audio_gear > 0 and wheel_rpm*float(ratios[audio_gear])*float(p.final_drive) < float(p.automatic_downshift_rpm):
		audio_gear -= 1
	var rpm := clampf(wheel_rpm*float(ratios[audio_gear])*float(p.final_drive), p.idle_rpm, p.redline_rpm)
	var load := clampf(0.55 + acceleration*0.08, 0.0, 1.0) if speed > 0.5 else 0.0
	return Vector3(rpm, load, 1)
