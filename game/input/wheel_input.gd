extends CanvasLayer
## Per-control device bindings allow separate USB pedals. Calibration also handles inverted axes.
const SAVE_PATH := "user://wheel_controls.cfg"
var bindings: Dictionary = {}
var panel: PanelContainer
var status: Label
var enabled: CheckButton
var capture := ""
var candidate: Dictionary = {}
var origins: Dictionary = {}
var samples: Array[float] = []
var player: Node

func _ready() -> void:
	layer = 20
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		bindings = config.get_value("wheel", "bindings", {})
	panel = PanelContainer.new()
	panel.position = Vector2(25, 25)
	panel.custom_minimum_size = Vector2(610, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "Wheel setup — F10 to close"
	box.add_child(title)
	var notice := Label.new()
	notice.text = "CAR HELD ON BRAKES WHILE SETUP IS OPEN\nValues below preview inputs. Enable controls, then close to drive."
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(notice)
	enabled = CheckButton.new()
	enabled.text = "Enable calibrated wheel and pedals"
	enabled.button_pressed = config.get_value("wheel", "enabled", false)
	enabled.toggled.connect(func(_value): _save())
	box.add_child(enabled)
	for control in ["steer", "throttle", "brake", "shift_up", "shift_down"]:
		var button := Button.new()
		button.text = "Calibrate " + control.replace("_", " ")
		button.pressed.connect(_begin.bind(control))
		box.add_child(button)
	var next := Button.new()
	next.text = "Capture position / finish calibration"
	next.pressed.connect(_confirm)
	box.add_child(next)
	var clear := Button.new()
	clear.text = "Clear bindings"
	clear.pressed.connect(func(): bindings.clear(); capture = ""; _save())
	box.add_child(clear)
	var close := Button.new()
	close.text = "Close setup and return to driving (F10)"
	close.pressed.connect(_close_setup)
	box.add_child(close)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	panel.hide()

func _close_setup() -> void:
	capture = ""
	var race_ui = player.get_parent().get_node_or_null("HUD/RaceUI") if is_instance_valid(player) else null
	if race_ui != null:
		race_ui.close_shell()
	else:
		panel.hide()

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("wheel", "bindings", bindings)
	config.set_value("wheel", "enabled", enabled.button_pressed)
	if config.save(SAVE_PATH) != OK:
		push_warning("Could not save wheel calibration")

func _device(binding: Dictionary) -> int:
	for device in Input.get_connected_joypads():
		if Input.get_joy_guid(device) == binding.get("guid", "") and Input.get_joy_name(device) == binding.get("name", ""):
			return device
	return -1

func _begin(control: String) -> void:
	capture = control
	candidate = {}
	samples.clear()
	origins.clear()
	for device in Input.get_connected_joypads():
		for axis in range(JOY_AXIS_MAX):
			origins[Vector2i(device, axis)] = Input.get_joy_axis(device, axis)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		capture = ""
		var race_ui = player.get_parent().get_node_or_null("HUD/RaceUI") if is_instance_valid(player) else null
		if race_ui != null:
			race_ui.toggle_page("controls")
		else:
			panel.visible = not panel.visible
		get_viewport().set_input_as_handled()
	if panel.is_visible_in_tree():
		if not capture.is_empty() and event is InputEventJoypadMotion and samples.is_empty():
			var key := Vector2i(event.device, event.axis)
			if absf(event.axis_value - float(origins.get(key, 0))) > 0.25:
				candidate = {"guid": Input.get_joy_guid(event.device), "name": Input.get_joy_name(event.device), "axis": event.axis}
		if capture.begins_with("shift") and event is InputEventJoypadButton and event.pressed:
			bindings[capture] = {"guid": Input.get_joy_guid(event.device), "name": Input.get_joy_name(event.device), "button": event.button_index}
			capture = ""
			_save()
		if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()
	elif enabled.button_pressed and event is InputEventJoypadButton and event.pressed and is_instance_valid(player):
		if not player.driving_enabled or player.player_state.pit_stall_state == player.player_state.StallState.STOPPED:
			return
		for control in ["shift_up", "shift_down"]:
			var binding: Dictionary = bindings.get(control, {})
			if event.device == _device(binding) and event.button_index == binding.get("button", -1):
				player.sim.automatic = false
				player.sim.select_gear(clampi(player.sim.gear + (1 if control == "shift_up" else -1), -1, 6))

func _confirm() -> void:
	if capture.is_empty() or capture.begins_with("shift") or candidate.is_empty():
		return
	var device := _device(candidate)
	if device < 0:
		return
	samples.append(Input.get_joy_axis(device, candidate.axis))
	var count := 3 if capture == "steer" else 2
	if samples.size() < count:
		return
	var valid := absf(samples[0] - samples[1]) > 0.1
	if capture == "steer":
		valid = valid and (samples[0] - samples[1]) * (samples[2] - samples[1]) < 0 and absf(samples[2] - samples[1]) > 0.1
	if valid:
		candidate["positions"] = samples.duplicate()
		bindings[capture] = candidate.duplicate(true)
		capture = ""
		_save()
	else:
		samples.clear()

static func normalize_axis(value: float, positions: Array, steering: bool) -> float:
	if steering:
		var offset: float = value - positions[1]
		var left: float = positions[0] - positions[1]
		var right: float = positions[2] - positions[1]
		var amount := offset / left if offset * left >= 0 else -offset / right
		return signf(amount) * clampf((absf(amount) - 0.015) / 0.985, 0, 1)
	return clampf(((value - positions[0]) / (positions[1] - positions[0]) - 0.02) / 0.96, 0, 1)

func axis_value(control: String) -> float:
	var binding: Dictionary = bindings.get(control, {})
	var device := _device(binding)
	if device < 0 or not binding.has("positions"):
		return 0
	return normalize_axis(Input.get_joy_axis(device, binding.axis), binding.positions, control == "steer")

func controls() -> Vector3:
	if panel.is_visible_in_tree():
		return Vector3(0, 1, 0)
	var keyboard := Vector3(Input.get_action_strength("drive_accelerate"), Input.get_action_strength("drive_brake"), Input.get_axis("drive_right", "drive_left"))
	if not enabled.button_pressed:
		return keyboard
	# Missing devices release their inputs; keyboard remains usable.
	return Vector3(maxf(keyboard.x, axis_value("throttle")), maxf(keyboard.y, axis_value("brake")), keyboard.z if absf(keyboard.z) > 0 else axis_value("steer"))

func _process(_delta: float) -> void:
	if not panel.is_visible_in_tree():
		return
	var names: Array[String] = []
	for device in Input.get_connected_joypads():
		names.append(Input.get_joy_name(device))
	status.text = "Devices: " + (", ".join(names) if not names.is_empty() else "none detected — connect wheel/pedals")
	status.text += "\nSteer %+.2f    Throttle %.2f    Brake %.2f" % [axis_value("steer"), axis_value("throttle"), axis_value("brake")]
	status.text += "\nBound: " + ", ".join(bindings.keys())
	if not capture.is_empty():
		if capture.begins_with("shift"):
			status.text += "\nPress the desired paddle/button."
		else:
			var steps := ["Turn fully LEFT", "Return to CENTRE", "Turn fully RIGHT"] if capture == "steer" else ["Move pedal to identify it, then RELEASE fully", "PRESS pedal fully"]
			status.text += "\n" + steps[samples.size()] + ", then click Capture."
			status.text += "\nSelected: " + str(candidate.get("name", "move the desired axis"))
	else:
		status.text += "\nCalibrate each axis, then enable. Practice continues while setup is open.\nPlayer throttle is cut and brakes applied during setup."
