extends VBoxContainer
var shell: Node
var front: SpinBox
var preview: Label
var status: Label
var apply_button: Button
var dynamic_body: CheckBox
var wheel_travel: CheckBox
var suspension_info: Label

func _ready() -> void:
	add_theme_constant_override("separation",18)
	var help := Label.new()
	help.text = "Front / rear roll stiffness balance\nMore front generally adds understeer; more rear encourages rotation.\nThis changes cornering load transfer, not static weight or wing balance.\nApply saves this setting for the current track."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)
	var row := HBoxContainer.new()
	add_child(row)
	var caption := Label.new()
	caption.text = "Front roll stiffness"
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	front = SpinBox.new()
	front.min_value = 35
	front.max_value = 65
	front.step = 1
	front.suffix = "%"
	front.custom_minimum_size.x = 180
	row.add_child(front)
	preview = Label.new()
	add_child(preview)
	dynamic_body = CheckBox.new()
	dynamic_body.text = "Dynamic suspension (Indianapolis test)"
	add_child(dynamic_body)
	wheel_travel = CheckBox.new()
	wheel_travel.text = "Heave and wheel travel"
	add_child(wheel_travel)
	suspension_info = Label.new()
	suspension_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(suspension_info)
	front.value_changed.connect(func(value: float): preview.text = "Rear roll stiffness: %.0f%%" % (100-value))
	apply_button = Button.new()
	apply_button.text = "Apply Roll Balance"
	apply_button.custom_minimum_size.y = 44
	apply_button.pressed.connect(_apply)
	add_child(apply_button)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	refresh()

func refresh() -> void:
	front.value = shell.practice.player.sim.p.front_roll_stiffness_fraction*100.0
	preview.text = "Rear roll stiffness: %.0f%%" % (100-front.value)
	status.text = ""
	var suspension = shell.practice.player.sim.suspension
	dynamic_body.visible = suspension.profile_id != "disabled"
	wheel_travel.visible = dynamic_body.visible
	suspension_info.visible = dynamic_body.visible
	dynamic_body.button_pressed = suspension.enabled
	wheel_travel.button_pressed = suspension.wheel_travel_enabled
	suspension_info.text = "ICR2 Indy reference: LF 85 / RF 70 / LR 75 / RR 65.\nHeave and wheel travel adds road-driven spring/damper support.\nUncheck travel to compare with the accepted roll/pitch model."

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		apply_button.disabled = not shell.practice.player.can_adjust_aero()
		dynamic_body.disabled = apply_button.disabled
		wheel_travel.disabled = apply_button.disabled

func _apply() -> void:
	front.apply()
	var error: Error = shell.practice.player.save_roll_setup(front.value/100.0)
	if error == OK and dynamic_body.visible:
		error = shell.practice.player.save_suspension_enabled(dynamic_body.button_pressed,wheel_travel.button_pressed)
	status.text = "Roll balance applied and saved." if error == OK else "Could not apply roll balance: "+error_string(error)
	if error == OK and dynamic_body.visible:
		status.text = "Roll balance and body response applied and saved."
