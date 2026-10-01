extends SceneTree
## Silent-to-speakers, real-time audition rendered through the actual engine mixer.
## 0-10s cockpit, 10-20s exterior, 20-24s pass, 24-27s field, 27-28s shutdown.
class BoothCockpit extends Node3D:
	var camera: Camera3D

var car: Node3D
var exterior: Camera3D
var booth: BoothCockpit
var field: Array[Node3D] = []
var recorder: AudioEffectRecord
var elapsed := 0.0
var started := false
var done := false

func _initialize() -> void:
	call_deferred("setup")

func setup() -> void:
	AudioServer.set_bus_volume_db(0, -80.0)
	car = load("res://content/vehicles/open_wheel/scenes/player_vehicle.tscn").instantiate()
	car.human_controlled = false
	booth = BoothCockpit.new()
	booth.name = "Cockpit"
	booth.camera = Camera3D.new()
	booth.add_child(booth.camera)
	car.add_child(booth)
	root.add_child(car)
	booth.camera.make_current()
	exterior = Camera3D.new()
	root.add_child(exterior)
	exterior.position = Vector3(0, 2, 8)
	exterior.look_at(Vector3.ZERO)
	recorder = AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Engines"), recorder)
	recorder.set_recording_active(true)
	started = true

func _process(delta: float) -> bool:
	if not started or done:
		return false
	elapsed += delta
	var stage := fmod(elapsed, 10.0)
	var rpm := 2500.0
	var throttle := 0.0
	if stage >= 2.0 and stage < 7.0:
		rpm = lerpf(2500.0, 13800.0, (stage-2.0)/5.0)
		throttle = 1.0
	elif stage >= 7.0 and stage < 8.0:
		rpm = lerpf(13800.0, 11000.0, stage-7.0)
	elif stage >= 8.0:
		rpm = 10200.0
		throttle = 1.0
	car.sim.engine_omega = rpm*TAU/60.0
	car.sim.throttle = throttle
	car.sim.shift_remaining = 0.05 if stage >= 8.0 and stage < 8.12 else 0.0
	if elapsed >= 10.0 and not exterior.current:
		exterior.make_current()
	if elapsed >= 20.0 and elapsed < 24.0:
		exterior.position = Vector3(0, 2, 0)
		exterior.rotation = Vector3.ZERO
		car.position = Vector3((elapsed-22.0)*75.0, 0, -15)
		car.sim.engine_omega = 12000.0*TAU/60.0
		car.sim.throttle = 1.0
	if elapsed >= 24.0 and field.is_empty():
		car.position = Vector3.ZERO
		exterior.position = Vector3(0, 2, 8)
		exterior.look_at(Vector3.ZERO)
		for i in range(15):
			var other = load("res://content/vehicles/open_wheel/scenes/player_vehicle.tscn").instantiate()
			other.human_controlled = false
			root.add_child(other)
			other.position = Vector3((i%5-2)*3.0, 0, (i/5)*3.0)
			other.sim.engine_omega = (10500+i*180)*TAU/60.0
			other.sim.throttle = 1.0
			field.append(other)
	if elapsed >= 27.0:
		car.sim.set_engine_running(false)
		car.physics_ready = false
		for other in field:
			other.physics_ready = false
	if elapsed >= 28.0:
		done = true
		call_deferred("finish")
	return false

func finish() -> void:
	recorder.set_recording_active(false)
	var recording := recorder.get_recording()
	DirAccess.make_dir_recursive_absolute("res://builds")
	var error := recording.save_to_wav("res://builds/engine_audition.wav")
	var pcm := recording.data
	var peak := 0.0
	var energy := 0.0
	for i in range(0, pcm.size(), 2):
		var sample := absf(float(pcm.decode_s16(i))/32768.0)
		peak = maxf(peak, sample)
		energy += sample*sample
	var rms := sqrt(energy/maxf(1, pcm.size()/2))
	print("AUDIO CAPTURE seconds=%.2f peak=%.4f RMS=%.4f save=%s" % [recording.get_length(), peak, rms, error_string(error)])
	car.queue_free()
	exterior.queue_free()
	for other in field:
		other.queue_free()
	await process_frame
	quit(0 if error == OK and recording.get_length() > 26.0 and peak > 0.01 and peak < 0.99 else 1)
