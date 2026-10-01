extends VBoxContainer
const Aero = preload("res://game/vehicle/aero_model.gd")
var shell: Node
var package: OptionButton
var front: SpinBox
var rear: SpinBox
var preview: Label
var status: Label
var apply_button: Button

func _ready() -> void:
	add_theme_constant_override("separation",12)
	var help := Label.new()
	help.text = "More wing adds grip and drag. Front/rear settings change aero balance.\nApply saves this setup for the current track."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",24)
	grid.add_theme_constant_override("v_separation",10)
	add_child(grid)
	var body_label := Label.new()
	body_label.text = "Body package"
	grid.add_child(body_label)
	package = OptionButton.new()
	package.add_item("Speedway")
	package.add_item("Road course")
	grid.add_child(package)
	front = _wing_control(grid,"Front wing")
	rear = _wing_control(grid,"Rear wing")
	preview = Label.new()
	preview.add_theme_font_size_override("font_size",16)
	add_child(preview)
	apply_button = Button.new()
	apply_button.text = "Apply and save for this track"
	apply_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	apply_button.pressed.connect(_apply)
	add_child(apply_button)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.hide()
	add_child(status)
	package.item_selected.connect(func(_index: int): _preview())
	front.value_changed.connect(func(_value: float): _preview())
	rear.value_changed.connect(func(_value: float): _preview())

func _wing_control(grid: GridContainer, title: String) -> SpinBox:
	var label := Label.new()
	label.text = title
	grid.add_child(label)
	var control := SpinBox.new()
	control.min_value = 3.0
	control.max_value = 18.0
	control.step = 0.05
	control.suffix = "°"
	control.custom_minimum_size.x = 180
	grid.add_child(control)
	return control

func refresh() -> void:
	var p: Dictionary = shell.practice.player.sim.p
	package.select(0 if p.body_package == "speedway" else 1)
	front.set_value_no_signal(p.front_wing_deg)
	rear.set_value_no_signal(p.rear_wing_deg)
	status.text = ""
	status.hide()
	_preview()

func _preview() -> void:
	if shell == null or shell.practice == null:
		return
	var p: Dictionary = shell.practice.player.sim.p
	var result := Aero.areas("speedway" if package.selected == 0 else "road",front.value,rear.value,p.coefficient_area_scale)
	var pressure: float = 0.5*p.air_density_kg_m3*pow(300.0/3.6,2)
	preview.text = "At 300 km/h in still air\nDownforce: %.0f N   |   Drag: %.0f N\nFront aero balance: %.1f%%\nFront downforce: %.0f N   |   Rear downforce: %.0f N" % [pressure*result.downforce_area_m2,pressure*result.drag_area_m2,100.0*result.front_downforce_fraction,pressure*result.downforce_area_m2*result.front_downforce_fraction,pressure*result.downforce_area_m2*(1.0-result.front_downforce_fraction)]

func _process(_delta: float) -> void:
	if not is_visible_in_tree() or shell == null or shell.practice == null:
		return
	apply_button.disabled = not shell.practice.player.can_adjust_aero()
	apply_button.tooltip_text = "Park in your practice or qualifying pit box to apply changes." if apply_button.disabled else ""

func _apply() -> void:
	# Commit text still being edited before reading either angle.
	front.apply()
	rear.apply()
	var error: Error = shell.practice.player.save_aero_setup("speedway" if package.selected == 0 else "road",front.value,rear.value)
	status.text = "Setup applied and saved." if error == OK else "Setup could not be applied: "+error_string(error)
	status.show()
