extends Node
## Full-course yellow rules. Timing continues throughout; queue order is physical,
## independent of scored laps. No lap credits or wave-arounds are awarded.
enum Phase { GREEN, CLOSED, OPEN, ONE_TO_GREEN, RESTART }
const FUEL_FACTOR := 0.45
const QUEUE_GAP := 25.0
const CATCHUP_KPH := 130.0
var phase := Phase.GREEN
var main: Node
var queue: Array[Node3D] = []
var progress: Dictionary = {}
var last_position: Dictionary = {}
var committed: Dictionary = {}
var circuit := Curve3D.new()
var length := 0.0
var elapsed := 0.0
var phase_distance := 0.0
var reason := ""
var caution_count := 0
var previous_green_side := false
var merging: Dictionary = {}

func configure(scene: Node) -> void:
	main = scene
	process_physics_priority = -10
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main.track_session_file.get_base_dir()+"/ai/reference_paths.json"))
	for p in data.reference_path:
		circuit.add_point(Vector3(p[0],p[1],p[2]))
	length = circuit.get_baked_length()
	main.session.finished.connect(_finish)

func active() -> bool:
	return phase != Phase.GREEN and main.session.status == main.session.Status.RUNNING

func position_of(car: Node3D) -> float:
	return circuit.get_closest_offset(main.get_node("MileOval").to_local(car.global_position))

func call_caution(why: String = "Race control") -> bool:
	if main.session.session_type != main.session.SessionType.RACE or main.session.status != main.session.Status.RUNNING:
		return false
	if active():
		# An additional incident cancels an announced restart.
		if phase in [Phase.ONE_TO_GREEN,Phase.RESTART]:
			phase = Phase.OPEN
			elapsed = 0.0
			main.pace_car.deploy_caution(queue[0] if not queue.is_empty() else null,circuit)
			phase_distance = main.pace_car.caution_distance
		return false
	queue.clear()
	progress.clear()
	last_position.clear()
	committed.clear()
	merging.clear()
	for entry in main.lap_timing.track_order():
		if entry.get("retired",false) or entry.car.get_meta("withdrawing",false):
			continue
		var car: Node3D = entry.car
		if _in_pits(car):
			committed[car] = true
		else:
			queue.append(car)
	var leader: Node3D = queue[0] if not queue.is_empty() else null
	var lead_position := position_of(leader) if leader != null else 0.0
	var initial_order := queue.duplicate()
	queue.sort_custom(func(a: Node3D,b: Node3D) -> bool:
		var a_gap := fposmod(lead_position-position_of(a),length)
		var b_gap := fposmod(lead_position-position_of(b),length)
		return initial_order.find(a) < initial_order.find(b) if is_equal_approx(a_gap,b_gap) else a_gap < b_gap)
	for car in queue:
		last_position[car] = position_of(car)
		progress[car] = lead_position-fposmod(lead_position-position_of(car),length)
	phase = Phase.CLOSED
	reason = why
	elapsed = 0.0
	caution_count += 1
	main.pace_car.deploy_caution(leader,circuit)
	_sync_drivers(0.0)
	return true

func _in_pits(car: Node3D) -> bool:
	var driver = car.get_node_or_null("Driver")
	if merging.has(car) and driver != null and driver.mode == driver.Mode.PIT_EXIT:
		return false
	return car.player_state.is_in_pit_lane or (driver != null and driver.mode in [driver.Mode.PIT_ENTRY,driver.Mode.PIT_EXIT,driver.Mode.WAITING])

func pits_open() -> bool:
	return not active() or phase != Phase.CLOSED

func may_service(car: Node3D) -> bool:
	return pits_open() or committed.has(car) or car.player_state.fuel_gal <= car.player_state.fuel_per_lap_gal

func commit_pit(car: Node3D) -> void:
	committed[car] = true
	queue.erase(car)

func should_pit(driver) -> bool:
	if not pits_open():
		# Emergency fuel is permitted, with a tail-of-queue return.
		return driver.car.player_state.fuel_gal <= driver.car.player_state.fuel_per_lap_gal
	var state = driver.car.player_state
	if state.fuel_gal <= driver.pit_fuel_trigger_gal:
		return true
	if not active() or phase != Phase.OPEN:
		return false
	var remaining: int = maxi(0,main.session.race_laps-driver._timed_laps())
	return state.fuel_gal < state.fuel_capacity_gal*.8 and state.fuel_gal/state.fuel_per_lap_gal < remaining+1

func _physics_process(delta: float) -> void:
	if not active():
		return
	elapsed += delta
	for entry in main.lap_timing.entries:
		var car: Node3D = entry.car
		car.player_state.fuel_burn_factor = FUEL_FACTOR
		if entry.get("retired",false) or car.get_meta("withdrawing",false) or _in_pits(car):
			queue.erase(car)
			merging.erase(car)
			continue
		var at := position_of(car)
		if not car in queue:
			_append_to_queue(car)
		else:
			progress[car] += wrapf(at-float(last_position[car]),-length*.5,length*.5)
			last_position[car] = at
	if queue.is_empty():
		return
	main.pace_car.leader = queue[0]
	_sync_drivers(delta)
	var gathered := _gathered()
	match phase:
		Phase.CLOSED:
			if elapsed >= 15.0 and main.pace_car.caution_picked_up and gathered:
				phase = Phase.OPEN
				elapsed = 0.0
				phase_distance = main.pace_car.caution_distance
		Phase.OPEN:
			if main.pace_car.caution_distance-phase_distance >= length and gathered and not _ai_pitting():
				phase = Phase.ONE_TO_GREEN
				phase_distance = main.pace_car.caution_distance
				main.pace_car.model.flashing = false
		Phase.ONE_TO_GREEN:
			if main.pace_car.caution_distance-phase_distance >= length and gathered and not _ai_pitting():
				phase = Phase.RESTART
				main.pace_car.return_from_caution()
				previous_green_side = _in_green_zone()
		Phase.RESTART:
			var green_side := _in_green_zone()
			if green_side and not previous_green_side and main.pace_car.clear_of_track and gathered:
				_restart()
			previous_green_side = green_side

func _in_green_zone() -> bool:
	var p: Vector3 = main.get_node("MileOval").to_local(queue[0].global_position)
	return p.x >= main.track_data.green_point.x and p.z > 100.0

func _ai_pitting() -> bool:
	for car in main.ai_cars:
		var driver = car.get_node("Driver")
		if not driver.race_plan.retired and not driver.race_plan.returning and driver.mode in [driver.Mode.PIT_ENTRY,driver.Mode.PIT_EXIT,driver.Mode.WAITING]:
			return true
	return false

func _gathered() -> bool:
	if queue.is_empty():
		return false
	if phase != Phase.RESTART:
		var lead_gap := wrapf(position_of(main.pace_car)-position_of(queue[0]),-length*.5,length*.5)
		if not main.pace_car.caution_picked_up or lead_gap < 8.0 or lead_gap > 60.0:
			return false
	for i in range(queue.size()):
		if queue[i].speed_mps > CATCHUP_KPH/3.6+1.0:
			return false
		if i > 0:
			var gap: float = progress[queue[i-1]]-progress[queue[i]]
			if gap < 5.0 or gap > QUEUE_GAP+20.0:
				return false
	return true

func may_merge(driver) -> bool:
	if not active():
		return true
	if queue.is_empty():
		return true
	var tail := queue[-1]
	var join: Vector3 = driver._sample_path(driver.route,driver.route_distances,driver.merge_gate_m)
	var join_at := circuit.get_closest_offset(join)
	var passed := wrapf(position_of(tail)-join_at,-length*.5,length*.5)
	# Hold on the apron until the entire train has passed the merge point.
	return passed > QUEUE_GAP+10.0

func reserve_merge(car: Node3D) -> void:
	if active():
		merging[car] = true
		if not car in queue:
			_append_to_queue(car)

func _append_to_queue(car: Node3D) -> void:
	# Reserve a slot while still on the exit route, so subsequent pit cars
	# follow at queue spacing instead of waiting a whole route behind it.
	var at := position_of(car)
	var anchor: float = progress[queue[-1]] if not queue.is_empty() else at
	var anchor_at: float = last_position[queue[-1]] if not queue.is_empty() else at
	progress[car] = anchor+wrapf(at-anchor_at,-length*.5,length*.5)
	last_position[car] = at
	queue.append(car)

func target_speed(car: Node3D) -> float:
	var slot := queue.find(car)
	var pace: float = main.track_data.pace_speed_kph/3.6
	if slot < 0:
		return pace
	var gap := QUEUE_GAP
	var ahead_speed := pace
	if slot > 0:
		gap = progress[queue[slot-1]]-progress[car]
		ahead_speed = maxf(0,queue[slot-1].speed_mps)
		if gap < 5.0:
			# Retain walking pace so an out-of-position car can steer aside.
			return 3.0
	elif main.pace_car.caution_picked_up and phase != Phase.RESTART:
		gap = wrapf(position_of(main.pace_car)-position_of(car),-length*.5,length*.5)
		ahead_speed = main.pace_car.speed_mps
	# An illegally passed car must yield. Never wrap a negative queue gap into
	# a whole lap of catch-up, and never change scored laps to repair the queue.
	return clampf(ahead_speed+(gap-QUEUE_GAP)*.5,0.0,CATCHUP_KPH/3.6)

func _sync_drivers(delta: float) -> void:
	for car in queue:
		car.player_state.fuel_burn_factor = FUEL_FACTOR
		var driver = car.get_node_or_null("Driver")
		if driver == null:
			continue
		if driver.mode == driver.Mode.RACING:
			var lateral: float = driver.racecraft.coordinates(driver,car).y if driver.racecraft.enabled else 0.0
			driver.start_formation(lateral,main.track_data.pace_speed_kph)
		if driver.mode == driver.Mode.FORMATION:
			var slot := queue.find(car)
			var yield_lane := 0.0
			if slot > 0 and progress[queue[slot-1]]-progress[car] < 8.0:
				# If a car overshoots during deceleration or arrives ahead of its
				# slot, leave a clear inside lane for its assigned predecessor.
				yield_lane = 5.0
			driver.formation_lane_m = move_toward(driver.formation_lane_m,yield_lane,delta*.7)
			driver.formation_speed_kph = target_speed(car)*3.6

func player_instruction() -> String:
	if not active():
		return ""
	var label: String = ["","YELLOW — PITS CLOSED","YELLOW — PITS OPEN","ONE TO GREEN — PITS OPEN","PACE CAR IN — HOLD UNTIL GREEN"][phase]
	if phase == Phase.CLOSED and elapsed < 10.0:
		label += "\n"+reason
	var car: Node3D = main.player
	if _in_pits(car):
		return label+("\nWAIT FOR PITS TO OPEN" if not may_service(car) else "\nJOIN THE TAIL ON EXIT")
	var slot := queue.find(car)
	if slot > 0:
		var ahead := queue[slot-1]
		var gap: float = progress[ahead]-progress[car]
		label += "\n%s %s  •  %.0f km/h" % ["LET THROUGH:" if gap < 5.0 else "FOLLOW",str(ahead.get_meta("driver_name","Player")),target_speed(car)*3.6]
	else:
		label += "\nFOLLOW PACE CAR  •  %.0f km/h" % (target_speed(car)*3.6)
	return label

func _restart() -> void:
	phase = Phase.GREEN
	main.green_banner_seconds = 4.0
	for car in main.ai_cars:
		if not car.get_meta("retired",false):
			car.get_node("Driver").release_to_race()
	for entry in main.lap_timing.entries:
		entry.car.player_state.fuel_burn_factor = 1.0
	queue.clear()
	committed.clear()
	merging.clear()

func _finish() -> void:
	# A lap-limited race may finish under yellow; no extra green lap is added.
	if phase != Phase.GREEN:
		main.pace_car.return_from_caution()
		_restart()
		main.green_banner_seconds = 0.0
