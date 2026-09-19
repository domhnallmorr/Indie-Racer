extends PanelContainer
var practice: Node
@export var embedded := false
var shell: Control
var choices := OptionButton.new()
var seed_input := SpinBox.new()
var preview := Label.new()
var start := Button.new()
var paths: Array[String] = []
var record_ai := CheckButton.new()
var session_choice := OptionButton.new()

func _ready() -> void:
	if not embedded:
		set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		offset_left = -440
		offset_right = -18
		offset_top = 18
		custom_minimum_size = Vector2(410,0)
	else:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
	z_index = 20
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.025,.04,.06,.98)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	add_child(column)
	var title := Label.new()
	title.text = "Choose the session format and starting field"
	title.add_theme_font_size_override("font_size",18)
	column.add_child(title)
	session_choice.add_item("Practice")
	session_choice.add_item("%d-lap rolling-start race" % practice.track_data.race_laps)
	session_choice.add_item("10-minute qualifying")
	session_choice.select(["practice", "race", "qualifying"].find(practice.session_mode))
	column.add_child(session_choice)
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
	_update_start_text()
	column.add_child(start)
	start.disabled = paths.is_empty()
	start.pressed.connect(func():
		var selection: Dictionary = get_tree().root.get_meta("roster_selection", {}).duplicate(true)
		if paths[choices.selected] != practice.roster_file or session_choice.selected == 2:
			selection.erase("qualifying_grid")
			selection.erase("qualifying_results")
		selection.merge({"file":paths[choices.selected],"seed":int(seed_input.value),"ai_telemetry":record_ai.button_pressed,"session_mode":["practice", "race", "qualifying"][session_choice.selected],"race_laps":practice.track_data.race_laps,"max_fuel_capacity_gal":practice.max_fuel_capacity_gal}, true)
		get_tree().root.set_meta("roster_selection", selection)
		get_tree().reload_current_scene())
	var weekend := Button.new()
	weekend.text = "Return to Race Weekend"
	weekend.pressed.connect(practice._return_to_weekend)
	column.add_child(weekend)
	choices.item_selected.connect(func(_index): _preview())
	session_choice.item_selected.connect(func(_index): _update_start_text())
	_preview()
	if not embedded:
		hide()

func _update_start_text() -> void:
	start.text = "Start %d-lap race" % practice.track_data.race_laps if session_choice.selected == 1 else ("Restart qualifying" if session_choice.selected == 2 else "Restart practice")

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
	if embedded:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		visible = not visible
		get_viewport().set_input_as_handled()
