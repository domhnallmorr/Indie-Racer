extends Node
const Rules = preload("res://game/race/incident_rules.gd")
var main: Node
var failure_progress := INF
var failure_type := Rules.Kind.ENGINE
var debris_progress := INF
var motion = preload("res://game/race/incident_motion.gd").new()
var smoke: CPUParticles3D

func configure(scene: Node) -> void:
	main = scene
	process_physics_priority = -5
	if main.session_mode != "race" or main.session.incident_mode == "off":
		return
	if main.session.incident_mode == "everyone":
		var event := Rules.schedule(main.active_seed ^ int("player_incidents".hash()),main.session.race_laps)
		failure_progress = event.progress
		failure_type = event.kind
	var rng := RandomNumberGenerator.new()
	rng.seed = main.active_seed ^ 0xDEB215
	if rng.randf() < Rules.DEBRIS_CHANCE:
		debris_progress = rng.randf_range(.10,.90)*main.session.race_laps

func _physics_process(delta: float) -> void:
	if main == null:
		return
	if motion.started:
		motion.update(main.player,main.race_control,main.player_state.stall_pose,delta)
		if motion.recovered and is_instance_valid(smoke):
			smoke.emitting = false
	if main.session_mode != "race" or main.session.status != main.session.Status.RUNNING or main.session.incident_mode == "off":
		return
	var control = main.race_control
	if is_finite(debris_progress) and control._race_progress() >= debris_progress and control.scripted_incident_allowed():
		debris_progress = INF
		control.call_caution("Debris on track")
	var car = main.player
	if main.session.incident_mode != "everyone" or car.get_meta("retired",false) or control.active():
		return
	if not is_finite(failure_progress) or main.player_state.is_in_pit_lane or main.player_state.pit_stall_state != main.player_state.StallState.NONE:
		return
	if Rules.progress(main.lap_timing,car) >= failure_progress:
		trigger(failure_type)

func trigger(kind: int) -> bool:
	var control = main.race_control
	var car = main.player
	var state = main.player_state
	if main.session_mode != "race" or main.session.status != main.session.Status.RUNNING or car.get_meta("retired",false) or state.terminal_failure or state.punctured:
		return false
	if kind == Rules.Kind.CRASH and (not control.scripted_incident_allowed() or not control.in_turn(car)):
		return false
	failure_progress = INF
	failure_type = kind
	state.incident_name = Rules.NAMES[kind]
	state.punctured = kind == Rules.Kind.PUNCTURE
	state.terminal_failure = not state.punctured
	if Rules.returns_to_pits(kind):
		state.limp_required = true
		car.set_meta("withdrawing",state.terminal_failure)
		return true
	state.set_engine_running(false)
	car.set_meta("retired",true)
	main.lap_timing.retire(car,state.incident_name)
	motion.begin(car,control,kind == Rules.Kind.CRASH)
	if kind == Rules.Kind.ENGINE:
		var effects = preload("res://game/race/ai_race_plan.gd").new()
		effects._create_smoke(car)
		smoke = effects.smoke
	control.call_caution(state.incident_name+": Player")
	return true
