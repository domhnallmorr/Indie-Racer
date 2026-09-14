extends PanelContainer
var practice: Node
var choices := OptionButton.new()
var seed_input := SpinBox.new()
var preview := Label.new()
var start := Button.new()
var paths: Array[String] = []
var record_ai := CheckButton.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -440
	offset_right = -18
	offset_top = 18
	custom_minimum_size = Vector2(410,0)
	z_index = 20
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.025,.04,.06,.98)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	add_child(column)
	var title := Label.new()
	title.text = "AI ROSTER — F12 to close"
	column.add_child(title)
	column.add_child(choices)
	paths = preload("res://game/race/roster_data.gd").discover()
	for path in paths:
		var model = preload("res://game/race/roster_data.gd").new()
		var data: Dictionary = model.read_json(path)
		choices.add_item(str(data.get("display_name",path.get_base_dir().get_file())))
		if path == practice.roster_file:
			choices.select(choices.item_count-1)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0,250)
	column.add_child(scroll)
	scroll.add_child(preview)
	var label := Label.new()
	label.text = "Session seed (-1 = new random session)"
	column.add_child(label)
	seed_input.min_value = -1
	seed_input.max_value = 2147483647
	seed_input.value = practice.roster_seed
	column.add_child(seed_input)
	var current := Label.new()
	current.text = "Current session seed: "+str(practice.active_seed)
	column.add_child(current)
	record_ai.text = "Record AI telemetry"
	record_ai.button_pressed = practice.ai_telemetry_enabled
	record_ai.tooltip_text = "Applies on restart. Player recording remains on F11."
	column.add_child(record_ai)
	start.text = "Restart practice with this roster"
	column.add_child(start)
	start.disabled = paths.is_empty()
	start.pressed.connect(func():
		get_tree().root.set_meta("roster_selection",{"file":paths[choices.selected],"seed":int(seed_input.value),"ai_telemetry":record_ai.button_pressed})
		get_tree().reload_current_scene())
	choices.item_selected.connect(func(_index): _preview())
	_preview()
	hide()

func _preview() -> void:
	if paths.is_empty():
		preview.text = "No rosters found"
		return
	var model = preload("res://game/race/roster_data.gd").new()
	if not model.load_roster(paths[choices.selected]):
		start.disabled = true
		preview.text = "Invalid roster: "+"; ".join(model.errors)
		return
	start.disabled = false
	preview.text = ""
	for entry in model.entries:
		preview.text += "#%s  %s — %s\n" % [entry.number,entry.driver_name,entry.team]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		visible = not visible
		get_viewport().set_input_as_handled()
