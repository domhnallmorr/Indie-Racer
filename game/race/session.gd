extends Node
## Session clock. Qualifying and race are reserved, not implemented.
signal finished
enum SessionType { PRACTICE, QUALIFYING, RACE }
enum Status { NOT_STARTED, RUNNING, FINISHED }
@export var practice_duration_seconds := 3600.0
var session_type: SessionType = SessionType.PRACTICE
var status: Status = Status.NOT_STARTED
var remaining_seconds := 0.0

func start_practice() -> void:
	session_type = SessionType.PRACTICE
	remaining_seconds = maxf(0.0, practice_duration_seconds)
	status = Status.RUNNING
	advance(0.0)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if status != Status.RUNNING:
		return
	remaining_seconds = maxf(0.0, remaining_seconds - maxf(0.0, delta))
	if remaining_seconds == 0.0:
		status = Status.FINISHED
		finished.emit()

func clock_text() -> String:
	var total := int(ceil(remaining_seconds))
	return "%02d:%02d" % [total / 60, total % 60]
