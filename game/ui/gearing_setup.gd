extends VBoxContainer
const Gearing = preload("res://game/vehicle/gearing_setup.gd")
var shell: Node
var final_drive: SpinBox
var gears: Array[SpinBox] = []
var speeds: Array[Label] = []
var summary: Label
var active_values: Label
var status: Label
var apply_button: Button

func _ready() -> void:
	add_theme_constant_override("separation",10)
	var help := Label.new()
	help.text = "Lower ratios give more speed per RPM; higher ratios give more wheel torque.\nSpeeds below assume no tyre slip. Power and drag may limit speed sooner."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help)
	active_values = _label(self,"")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",20)
	grid.add_theme_constant_override("v_separation",6)
	add_child(grid)
	_label(grid,"Final drive")
	final_drive = _ratio(grid,2.0,6.0)
	_label(grid,"Affects all gears, including reverse")
	for title in ["Gear","Ratio","Auto shift / redline (km/h)"]:
		_label(grid,title)
	for i in range(6):
		_label(grid,str(i+1))
		gears.append(_ratio(grid,0.5,5.0))
		speeds.append(_label(grid,""))
	summary = _label(self,"")
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	apply_button = Button.new()
	apply_button.text = "Apply and save for this track"
	apply_button.pressed.connect(_apply)
	add_child(apply_button)
	status = _label(self,"")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.hide()
	final_drive.value_changed.connect(func(_value: float): _preview())
	for control in gears:
		control.value_changed.connect(func(_value: float): _preview())

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",16)
	parent.add_child(label)
	return label

func _ratio(parent: Node, minimum: float, maximum: float) -> SpinBox:
	var control := SpinBox.new()
	control.min_value = minimum
	control.max_value = maximum
	control.step = 0.01
	control.select_all_on_focus = true
	control.custom_minimum_size.x = 140
	parent.add_child(control)
	return control

func _ratios() -> Array:
	var result: Array = []
	for control in gears:
		result.append(control.value)
	return result

func refresh() -> void:
	var p: Dictionary = shell.practice.player.sim.p
	final_drive.set_value_no_signal(p.final_drive)
	for i in range(6):
		gears[i].set_value_no_signal(p.forward_ratios[i])
	status.hide()
	_show_active()
	_preview()

func _show_active() -> void:
	var p: Dictionary = shell.practice.player.sim.p
	active_values.text = "ACTIVE IN CAR: final drive %.2f   |   sixth %.2f" % [p.final_drive,p.forward_ratios[5]]

func _preview() -> void:
	var p: Dictionary = shell.practice.player.sim.p
	for i in range(6):
		var redline := Gearing.speed_kph(p.redline_rpm,p.rear_radius_m,final_drive.value,gears[i].value)
		var shift := Gearing.speed_kph(p.automatic_upshift_rpm,p.rear_radius_m,final_drive.value,gears[i].value)
		speeds[i].text = ("%.1f / %.1f" % [shift,redline]) if i < 5 else ("— / %.1f" % redline)
	var top := Gearing.speed_kph(p.redline_rpm,p.rear_radius_m,final_drive.value,gears[5].value)
	summary.text = "Sixth at 345 km/h: %.0f RPM   |   Redline: %.0f RPM" % [p.redline_rpm*345.0/top,p.redline_rpm]
	if not Gearing.valid(final_drive.value,_ratios()):
		summary.text = "Ratios must decrease from first to sixth."
	elif final_drive.value != p.final_drive or _ratios() != p.forward_ratios:
		summary.text += "\nUNSAVED CHANGES — use Apply below."

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	apply_button.disabled = not shell.practice.player.can_adjust_aero() or not Gearing.valid(final_drive.value,_ratios())
	apply_button.tooltip_text = "Park in your practice or qualifying pit box. Ratios must decrease from first to sixth."

func _apply() -> void:
	final_drive.apply()
	for control in gears:
		control.apply()
	var error: Error = shell.practice.player.save_gearing_setup(final_drive.value,_ratios())
	status.text = ("Applied and saved: final drive %.2f, sixth %.2f" % [shell.practice.player.sim.p.final_drive,shell.practice.player.sim.p.forward_ratios[5]]) if error == OK else "Could not apply gearing: "+error_string(error)
	_show_active()
	_preview()
	status.show()
