extends Camera3D
## Exterior and TV cameras. 1/2/3/4: overview/pits/banking/car; T: TV.
const TV_CAMERA_POSITIONS := [
	Vector3(65, 11, 158),
	Vector3(255, 13, 154),
	Vector3(354, 15, 25),
	Vector3(150, 11, -158),
	Vector3(-150, 11, -158),
	Vector3(-354, 15, -25),
	Vector3(-255, 13, 154),
	Vector3(-70, 11, 158),
]
const TV_SWITCH_ADVANTAGE_M := 45.0

var target := Vector3(51.79594, 0.45, 129)
var distance := 7.0
var yaw := 0.8
var pitch := 0.35
var follow_player := true
var followed_ai := -1
var tv_mode := false
var tv_camera_index := -1

func _process(_delta: float) -> void:
	if not current:
		return
	if tv_mode:
		_update_tv_camera()
	elif follow_player:
		focus_player()

func _ready() -> void:
	cull_mask = 19
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and current and not tv_mode and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * 0.005
		pitch = clampf(pitch + event.relative.y * 0.005, 0.08, 1.55)
		_update_camera()
		return
	if event is InputEventMouseButton and current and not tv_mode and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(2.0, distance * 0.88)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(1600.0, distance / 0.88)
		_update_camera()
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.keycode
	if event.physical_keycode in [KEY_KP_ADD,KEY_KP_SUBTRACT]:
		key = event.physical_keycode
	var activates_exterior: bool = key in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_6, KEY_7, KEY_T, KEY_KP_ADD, KEY_KP_SUBTRACT]
	if activates_exterior:
		make_current()
	if not current:
		return
	if key in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_6, KEY_7]:
		fov = 75.0
	match key:
		KEY_1:
			tv_mode = false
			follow_player = false
			target = Vector3.ZERO
			distance = 850.0
			yaw = 0.35
			pitch = 0.9
		KEY_2:
			tv_mode = false
			follow_player = false
			target = Vector3(30, 0, 100)
			distance = 170.0
			yaw = 0.0
			pitch = 0.7
		KEY_3:
			tv_mode = false
			follow_player = false
			target = Vector3(322, 0, 0)
			distance = 90.0
			yaw = -1.57
			pitch = 0.25
		KEY_4:
			tv_mode = false
			followed_ai = -1
			follow_player = true
			distance = 7.0
			yaw = 0.8
			pitch = 0.35
			focus_player()
		KEY_6, KEY_7:
			tv_mode = false
			var count: int = get_parent().ai_cars.size()
			if count == 0:
				return
			if followed_ai < 0:
				followed_ai = 0 if key == KEY_6 else mini(1,count-1)
			else:
				followed_ai = posmod(followed_ai+(-1 if key == KEY_6 else 1),count)
			follow_player = true
			distance = 12.0
			pitch = .45
			focus_player()
		KEY_T:
			_activate_tv()
		KEY_KP_ADD, KEY_KP_SUBTRACT:
			_cycle_tv_subject(1 if key == KEY_KP_ADD else -1)
	_update_camera()

func _update_camera() -> void:
	if tv_mode:
		_update_tv_camera()
		return
	position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	look_at(target)

func followed_subject() -> Node3D:
	if followed_ai >= 0 and followed_ai < get_parent().ai_cars.size():
		return get_parent().ai_cars[followed_ai]
	return get_parent().get_node("DisplayCar")

func focus_player() -> void:
	var subject := followed_subject()
	target = subject.global_position + Vector3(0, .45, 0)
	_update_camera()

func _activate_tv() -> void:
	tv_mode = true
	follow_player = false
	tv_camera_index = -1
	fov = 42.0
	_update_tv_camera(true)

func _cycle_tv_subject(direction: int) -> void:
	var ordered := _ordered_cars()
	if ordered.is_empty():
		return
	var current_subject := followed_subject()
	var index := ordered.find(current_subject)
	if index < 0:
		index = 0 if direction < 0 else -1
	var selected: Node3D = ordered[posmod(index+direction,ordered.size())]
	followed_ai = get_parent().ai_cars.find(selected)
	_activate_tv()

func _ordered_cars() -> Array:
	var parent := get_parent()
	if parent.lap_timing != null:
		var ordered: Array = []
		for entry in parent.lap_timing.track_order():
			ordered.append(entry.car)
		return ordered
	return [parent.player] + parent.ai_cars

func followed_position() -> int:
	var index := _ordered_cars().find(followed_subject())
	return index + 1 if index >= 0 else 0

func _update_tv_camera(force_switch := false) -> void:
	var subject := followed_subject()
	if not is_instance_valid(subject):
		return
	var track: Node3D = get_parent().get_node("MileOval")
	var local_subject := track.to_local(subject.global_position)
	var best_index := 0
	var best_distance := INF
	for i in range(TV_CAMERA_POSITIONS.size()):
		var candidate_distance := Vector2(TV_CAMERA_POSITIONS[i].x-local_subject.x,TV_CAMERA_POSITIONS[i].z-local_subject.z).length()
		if candidate_distance < best_distance:
			best_distance = candidate_distance
			best_index = i
	if not force_switch and tv_camera_index >= 0:
		var active: Vector3 = TV_CAMERA_POSITIONS[tv_camera_index]
		var active_distance := Vector2(active.x-local_subject.x,active.z-local_subject.z).length()
		if active_distance <= best_distance + TV_SWITCH_ADVANTAGE_M:
			best_index = tv_camera_index
	tv_camera_index = best_index
	global_position = track.to_global(TV_CAMERA_POSITIONS[tv_camera_index])
	var speed: float = absf(float(subject.get("speed_mps"))) if subject.get("speed_mps") != null else 0.0
	var lead := -subject.global_basis.z * clampf(speed*.12,0.0,12.0)
	target = subject.global_position + lead + Vector3.UP*.7
	look_at(target)
