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
		if absf(lateral) > gate.half_width_m or crossing.y < -1 or crossing.y > 6:
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

static func format_lap(seconds: float) -> String:
	if seconds <= 0:
		return "--:--.---"
	var milliseconds := int(round(seconds*1000))
	return "%d:%02d.%03d" % [milliseconds/60000,(milliseconds/1000)%60,milliseconds%1000]
