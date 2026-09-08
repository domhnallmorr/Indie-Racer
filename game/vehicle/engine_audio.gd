extends AudioStreamPlayer
## Lightweight placeholder V8 tone, driven by actual engine speed and throttle.
## Non-spatial so physics feedback remains audible with every camera.
@export_range(-40.0, 0.0) var engine_volume_db := -15.0
const SAMPLE_RATE := 22050.0
var vehicle: Node
var playback: AudioStreamGeneratorPlayback
var phase := 0.0
var crank_phase := 0.0
var audible_rpm := 0.0
var audible_load := 0.0
var gain := 0.0

func _ready() -> void:
	vehicle = get_parent()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = SAMPLE_RATE
	generator.buffer_length = 0.08
	stream = generator
	volume_db = engine_volume_db
	play()
	playback = get_stream_playback() as AudioStreamGeneratorPlayback

func _process(_delta: float) -> void:
	if playback == null:
		return
	var running: bool = vehicle.physics_ready and vehicle.driving_enabled
	var target_rpm: float = vehicle.engine_rpm if running else 0.0
	var target_load: float = vehicle.sim.throttle if running else 0.0
	if vehicle.sim.shift_remaining > 0.0:
		target_load = 0.0
	var frames := playback.get_frames_available()
	var buffer := PackedVector2Array()
	buffer.resize(frames)
	for i in range(frames):
		# Sample-based smoothing preserves phase and avoids clicks on shifts/reset.
		audible_rpm += (target_rpm - audible_rpm) * (1.0 - exp(-1.0 / (SAMPLE_RATE * 0.025)))
		audible_load += (target_load - audible_load) * (1.0 - exp(-1.0 / (SAMPLE_RATE * 0.015)))
		gain = move_toward(gain, 1.0 if running else 0.0, 1.0 / (SAMPLE_RATE * 0.04))
		var crank_hz := clampf(audible_rpm, 0.0, 18000.0) / 60.0
		crank_phase = fmod(crank_phase + TAU * crank_hz / SAMPLE_RATE, TAU)
		# Four firing pulses per revolution for a four-stroke V8.
		phase = fmod(phase + TAU * crank_hz * 4.0 / SAMPLE_RATE, TAU)
		var exhaust := sin(phase) * 0.52
		exhaust += sin(phase * 2.0) * lerpf(0.12, 0.25, audible_load)
		exhaust += sin(phase * 3.0) * lerpf(0.04, 0.12, audible_load)
		var rumble := sin(crank_phase) * 0.10 + sin(crank_phase * 2.0) * 0.08
		var sample := (exhaust + rumble) * lerpf(0.35, 0.8, audible_load) * gain
		buffer[i] = Vector2(sample, sample)
	playback.push_buffer(buffer)
