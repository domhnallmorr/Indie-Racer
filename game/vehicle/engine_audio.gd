extends AudioStreamPlayer3D
## Shared placeholder V8 loop. Godot spatializes it relative to the active camera.
@export_range(-40.0, 0.0) var engine_volume_db := -18.0
const SAMPLE_RATE := 22050
const BASE_RPM := 6000.0
static var engine_loop: AudioStreamWAV
var vehicle: Node
var audible_rpm := 2500.0
var audible_load := 0.0
var gain := 0.0
var audio_gear := 0
var previous_speed := 0.0

func _ready() -> void:
	vehicle = get_parent()
	position = Vector3(0, 0.5, 0.8)
	unit_size = 20.0
	max_distance = 650.0
	max_db = engine_volume_db
	volume_db = -80.0
	# An omnidirectional exhaust remains audible as cars pass behind the camera.
	attenuation_filter_cutoff_hz = 10000.0
	stream = _engine_loop()
	# Different crank phases keep a stationary field from sounding like one oscillator.
	play(float(get_instance_id() % 882) / SAMPLE_RATE)

static func _engine_loop() -> AudioStreamWAV:
	if engine_loop != null:
		return engine_loop
	# Four complete crank revolutions at 6000 RPM; seamless, mono PCM.
	# Reuse the original tone's firing harmonics and low crank rumble, synthesized
	# once instead of generating 22050 samples per second per car in GDScript.
	var frames := 882
	var samples := PackedByteArray()
	samples.resize(frames * 2)
	for i in range(frames):
		var crank := TAU * 4.0 * float(i) / frames
		var firing := crank * 4.0
		var sample := sin(firing)*0.52 + sin(firing*2.0)*0.20 + sin(firing*3.0)*0.08
		sample += sin(crank)*0.10 + sin(crank*2.0)*0.08
		samples.encode_s16(i*2, int(clampf(sample, -1.0, 1.0)*32767.0))
	engine_loop = AudioStreamWAV.new()
	engine_loop.format = AudioStreamWAV.FORMAT_16_BITS
	engine_loop.mix_rate = SAMPLE_RATE
	engine_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	engine_loop.loop_end = frames
	engine_loop.data = samples
	return engine_loop

func _process(delta: float) -> void:
	var state := _engine_state(delta)
	audible_rpm = lerpf(audible_rpm, state.x, 1.0-exp(-delta/0.025))
	audible_load = lerpf(audible_load, state.y, 1.0-exp(-delta/0.015))
	gain = move_toward(gain, state.z, delta/0.04)
	pitch_scale = clampf(audible_rpm/BASE_RPM, 0.2, 3.0)
	volume_db = engine_volume_db + linear_to_db(maxf(0.0001, lerpf(0.35, 0.8, audible_load)*gain))

func _engine_state(delta: float) -> Vector3:
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
	var acceleration := (speed-previous_speed)/maxf(delta, 0.001)
	previous_speed = speed
	var load := clampf(0.55 + acceleration*0.08, 0.0, 1.0) if speed > 0.5 else 0.0
	return Vector3(rpm, load, 1)
