extends Camera3D
## Inspection only; no driving input. 1/2/3/4: overview/pits/banking/car.
var target := Vector3(51.79594, 0.45, 129)
var distance := 7.0
var yaw := 0.8
var pitch := 0.35
var follow_player := true
var followed_ai := -1

func _process(_delta: float) -> void:
	if current and follow_player:
		focus_player()

func _ready() -> void:
	cull_mask = 19
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_6, KEY_7]:
		make_current()
	if not current:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * 0.005
		pitch = clampf(pitch + event.relative.y * 0.005, 0.08, 1.55)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(2.0, distance * 0.88)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(1600.0, distance / 0.88)
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				follow_player = false
				target = Vector3.ZERO
				distance = 850.0
				yaw = 0.35
				pitch = 0.9
			KEY_2:
				follow_player = false
				target = Vector3(30, 0, 100)
				distance = 170.0
				yaw = 0.0
				pitch = 0.7
			KEY_3:
				follow_player = false
				target = Vector3(322, 0, 0)
				distance = 90.0
				yaw = -1.57
				pitch = 0.25
			KEY_4:
				followed_ai = -1
				follow_player = true
				focus_player()
				distance = 7.0
				yaw = 0.8
				pitch = 0.35
			KEY_6, KEY_7:
				followed_ai = 0 if event.keycode == KEY_6 else 1
				follow_player = true
				distance = 12.0
				pitch = .45
				focus_player()
	_update_camera()

func _update_camera() -> void:
	position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	look_at(target)

func focus_player() -> void:
	var subject: Node3D = get_parent().get_node("DisplayCar")
	if followed_ai >= 0 and followed_ai < get_parent().ai_cars.size():
		subject = get_parent().ai_cars[followed_ai]
	target = subject.global_position + Vector3(0, .45, 0)
	_update_camera()
