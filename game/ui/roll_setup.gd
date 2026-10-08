extends VBoxContainer
var shell: Node
var front: SpinBox
var preview: Label
var status: Label
var apply_button: Button

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

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		apply_button.disabled = not shell.practice.player.can_adjust_aero()

func _apply() -> void:
	front.apply()
	var error: Error = shell.practice.player.save_roll_setup(front.value/100.0)
	status.text = "Roll balance applied and saved." if error == OK else "Could not apply roll balance: "+error_string(error)
