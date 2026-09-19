extends Node
## Ordered track gates; first start/finish crossing begins a timed lap.
var entries: Array[Dictionary] = []
var gates: Array = []
var clock := 0.0
var track: Node3D
var session: Node

func configure(track_node: Node3D, session_node: Node, vehicles: Array) -> void:
	track = track_node
	session = session_node
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/mile_oval/ai/timing_gates.json"))
	gates = data.gates
	for car in vehicles:
		entries.append({"car": car, "name": "Player" if car.name == "DisplayCar" else str(car.get_meta("driver_name",String(car.name).replace("AI_", "AI "))),
			"previous": track.to_local(car.global_position), "armed": false, "expected": 0,
			"started": 0.0, "laps": 0, "best": 0.0, "last": 0.0, "order": entries.size()})

func _physics_process(delta: float) -> void:
	if session == null or session.status != session.Status.RUNNING:
		return
	var previous_time := clock
	clock += delta
	for entry in entries:
		sample(entry, track.to_local(entry.car.global_position), previous_time, clock)

func sample(entry: Dictionary, position: Vector3, from_time: float, to_time: float) -> void:
	if entry.get("retired",false):
		return
	var previous: Vector3 = entry.previous
	entry.previous = position
	for i in range(gates.size()):
		var gate: Dictionary = gates[i]
		var center := Vector3(gate.point[0],gate.point[1],gate.point[2])
		var normal := Vector3(gate.normal[0],gate.normal[1],gate.normal[2])
		var before := (previous-center).dot(normal)
		var after := (position-center).dot(normal)
		var forward := before < 0 and after >= 0
		var backward := before > 0 and after <= 0
		if not forward and not backward:
			continue
		var fraction := before/(before-after)
		var crossing := previous.lerp(position,fraction)
		var lateral := (crossing-center).dot(normal.cross(Vector3.UP))
		# Race pit lane runs parallel to the front straight and bypasses part of
		# T1/T2. Accept the same ordered timing planes on its authored pavement.
		# Bound the extension so the opposite side's plane cannot reset this lap.
		var race_pit_crossing: bool = absf(lateral) <= 50.0 and session != null and session.session_type == session.SessionType.RACE and entry.car.track_data.contains_pit_lane(crossing)
		if (absf(lateral) > gate.half_width_m and not race_pit_crossing) or crossing.y < -1 or crossing.y > 6:
			continue
		if backward:
			entry.armed = false
			entry.expected = 0
			continue
		var at := lerpf(from_time,to_time,fraction)
		if i == 0:
			if entry.armed and entry.expected == 0:
				var lap: float = at-entry.started
				if lap > 0:
					entry.laps += 1
					entry.last = lap
					if entry.best == 0 or lap < entry.best:
						entry.best = lap
			entry.armed = true
			entry.expected = 1
			entry.started = at
		elif entry.armed and i == entry.expected:
			entry.expected = (i+1)%gates.size()

func retire(car: Node3D, reason: String) -> void:
	for entry in entries:
		if entry.car == car:
			entry["retired"] = true
			entry["retirement_reason"] = reason
			entry["retirement_time"] = clock

func invalidate(car: Node3D) -> void:
	for entry in entries:
		if entry.car == car:
			entry.armed = false
			entry.expected = 0
			entry.previous = track.to_local(car.global_position)

func reset_for_race() -> void:
	clock = 0.0
	for entry in entries:
		entry.previous = track.to_local(entry.car.global_position)
		entry["retired"] = false
		entry.armed = false
		entry.expected = 0
		entry.started = 0.0
		entry.laps = 0
		entry.best = 0.0
		entry.last = 0.0

func standings() -> Array[Dictionary]:
	var sorted := entries.duplicate()
	if session != null and session.session_type == session.SessionType.RACE:
		sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a.laps != b.laps:
				return a.laps > b.laps
			if a.get("retired",false) != b.get("retired",false):
				return not a.get("retired",false)
			var a_progress: int = 4 if a.expected == 0 and a.armed else int(a.expected)
			var b_progress: int = 4 if b.expected == 0 and b.armed else int(b.expected)
			if a_progress != b_progress:
				return a_progress > b_progress
			return a.order < b.order)
		return sorted
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.best == b.best:
			return a.order < b.order
		if a.best == 0:
			return false
		if b.best == 0:
			return true
		return a.best < b.best)
	return sorted

## Physical order around the circuit, independent of practice qualifying times.
## Checkpoint progress provides the main ordering; distance to the next checkpoint
## resolves cars which are in the same quarter of the lap.
func track_order() -> Array[Dictionary]:
	var sorted := entries.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_progress := _track_progress(a)
		var b_progress := _track_progress(b)
		if not is_equal_approx(a_progress,b_progress):
			return a_progress > b_progress
		return a.order < b.order)
	return sorted

func _track_progress(entry: Dictionary) -> float:
	var stage := int(entry.expected)
	if stage == 0 and entry.armed:
		stage = gates.size()
	var progress := float(entry.laps*gates.size()+stage)
	if gates.is_empty():
		return progress
	var next_index := stage%gates.size()
	var previous_index := posmod(next_index-1,gates.size())
	var previous_gate: Array = gates[previous_index].point
	var next_gate: Array = gates[next_index].point
	var previous := Vector3(previous_gate[0],previous_gate[1],previous_gate[2])
	var next := Vector3(next_gate[0],next_gate[1],next_gate[2])
	var position: Vector3 = entry.previous
	var travelled := Vector2(position.x-previous.x,position.z-previous.z).length()
	var remaining := Vector2(position.x-next.x,position.z-next.z).length()
	if travelled+remaining > .001:
		progress += clampf(travelled/(travelled+remaining),0.0,.999)
	return progress

static func format_lap(seconds: float) -> String:
	if seconds <= 0:
		return "--:--.---"
	var milliseconds := int(round(seconds*1000))
	return "%d:%02d.%03d" % [milliseconds/60000,(milliseconds/1000)%60,milliseconds%1000]
