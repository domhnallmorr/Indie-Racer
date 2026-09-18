extends Node
## Practice clock and lap-limited rolling-start race state.
signal finished
signal green_flag
enum SessionType { PRACTICE, QUALIFYING, RACE }
enum Status { NOT_STARTED, FORMATION, RUNNING, FINISHED }
@export var practice_duration_seconds := 3600.0
@export var race_laps := 10
var session_type: SessionType = SessionType.PRACTICE
var status: Status = Status.NOT_STARTED
var remaining_seconds := 0.0

func start_practice() -> void:
	session_type = SessionType.PRACTICE
	remaining_seconds = maxf(0.0, practice_duration_seconds)
	status = Status.RUNNING
	advance(0.0)

func start_race(laps: int = 10) -> void:
	session_type = SessionType.RACE
	race_laps = maxi(1,laps)
	remaining_seconds = 0.0
	status = Status.FORMATION

func show_green() -> void:
	if session_type != SessionType.RACE or status != Status.FORMATION:
		return
	status = Status.RUNNING
	green_flag.emit()

func finish_race() -> void:
	if session_type == SessionType.RACE and status != Status.FINISHED:
		status = Status.FINISHED
		finished.emit()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if status != Status.RUNNING or session_type != SessionType.PRACTICE:
		return
	remaining_seconds = maxf(0.0, remaining_seconds - maxf(0.0, delta))
	if remaining_seconds == 0.0:
		status = Status.FINISHED
		finished.emit()

func clock_text() -> String:
	var total := int(ceil(remaining_seconds))
	return "%02d:%02d" % [total / 60, total % 60]
