extends PanelContainer

var practice: Node
var shell: Control
var wheel_host: MarginContainer
var wheel_panel: PanelContainer
var menu_wheel: CanvasLayer
var handling_choice: OptionButton

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.025,.04,.06,.72)
	style.set_content_margin_all(18)
	add_theme_stylebox_override("panel",style)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var layout := HBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation",24)
	scroll.add_child(layout)
	var help := VBoxContainer.new()
	help.custom_minimum_size.x = 300
	layout.add_child(help)
	var title := Label.new()
	title.text = "DRIVING & CAMERA"
	title.add_theme_font_size_override("font_size",18)
	help.add_child(title)
	_add_handling_option(help)
	if is_instance_valid(practice) and practice.player.physics_ready:
		_add_driving_assists(help)
	var guide := Label.new()
	guide.text = "W / S\nThrottle / brake\n\nA / D\nSteer\n\nQ / E\nShift down / up\n\nM\nAutomatic / manual\n\nV / N\nReverse / neutral\n\nR\nReset to pit box or grid\n\n1–4\nExterior cameras\n\n5\nCockpit camera\n\n6 / 7\nPrevious / next opponent\n\nT\nTV trackside camera\n\nNumpad + / -\nNext / previous car in track order\n\nCockpit: [ / ] FOV\nPgUp / PgDn seat height\nHome resets cockpit view"
	guide.text += "\n\nF1 / F2 / F3 / F4 / F5\nLap Timing / Standings / Fuel / Tyres / Loads"
	guide.text += "\n\nF8\nCall a test caution during a race"
	guide.add_theme_font_size_override("font_size",14)
	help.add_child(guide)
	wheel_host = MarginContainer.new()
	wheel_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wheel_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(wheel_host)
	call_deferred("_embed_wheel_setup")

func _add_handling_option(parent: Control) -> void:
	var heading := Label.new()
	heading.text = "PLAYER HANDLING"
	parent.add_child(heading)
	var choice := OptionButton.new()
	handling_choice = choice
	choice.name = "HandlingModel"
	choice.add_item("Current handling", 0)
	choice.add_item("Experimental handling", 1)
	choice.add_item("Experimental: free front wheels", 2)
	_sync_handling_choice(DrivingOptions.experimental_handling)
	parent.add_child(choice)
	var hint := Label.new()
	hint.text = "Saved for future sessions.\nExperimental handling changes cornering balance.\nChoose Current handling to switch back."
	hint.add_theme_font_size_override("font_size",13)
	parent.add_child(hint)
	DrivingOptions.handling_changed.connect(_sync_handling_choice)
	choice.item_selected.connect(func(index: int):
		var error := DrivingOptions.set_experimental_handling(index > 0, index == 2)
		if error != OK:
			_sync_handling_choice(DrivingOptions.experimental_handling)
			hint.text = "Could not save handling selection."
	)

func _sync_handling_choice(enabled: bool) -> void:
	if is_instance_valid(handling_choice):
		handling_choice.select((2 if DrivingOptions.independent_front_rotation else 1) if enabled else 0)

func _add_driving_assists(parent: Control) -> void:
	var heading := Label.new()
	heading.text = "DRIVING ASSISTS (%)"
	parent.add_child(heading)
	var fields := {
		"assistance_strength": "Master strength",
		"steering_assistance": "Speed steering help",
		"stability_assistance": "Stability control",
		"traction_control": "Traction control",
		"anti_lock_brakes": "Anti-lock brakes",
	}
	for key in fields:
		var row := HBoxContainer.new()
		parent.add_child(row)
		var caption := Label.new()
		caption.text = fields[key]
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(caption)
		var amount := SpinBox.new()
		amount.name = key
		amount.min_value = 0
		amount.max_value = 100
		amount.step = 5
		amount.value = practice.player.sim.p[key]*100.0
		amount.value_changed.connect(func(value: float): practice.player.sim.p[key] = value/100.0)
		row.add_child(amount)
	var hint := Label.new()
	hint.text = "Changes apply this session.\nSpeed steering help: 100% reduces travel at speed.\n0% gives fixed full steering travel at all speeds.\nFor oversteer: stability and traction at 0%."
	hint.add_theme_font_size_override("font_size",13)
	parent.add_child(hint)

func _embed_wheel_setup() -> void:
	if is_instance_valid(menu_wheel):
		wheel_panel = menu_wheel.panel
	elif is_instance_valid(practice) and is_instance_valid(practice.player.wheel_input):
		wheel_panel = practice.player.wheel_input.panel
	else:
		return
	if not is_instance_valid(wheel_panel):
		return
	var old_parent := wheel_panel.get_parent()
	old_parent.remove_child(wheel_panel)
	wheel_host.add_child(wheel_panel)
	wheel_panel.position = Vector2.ZERO
	wheel_panel.custom_minimum_size = Vector2(0,0)
	wheel_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wheel_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wheel_panel.show()
