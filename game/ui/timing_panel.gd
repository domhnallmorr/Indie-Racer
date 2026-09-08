extends PanelContainer
var timing: Node
var rows: Array[Label] = []
var refresh_time := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -440
	offset_right = -18
	offset_top = 18
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.025,.04,.06,.94)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	add_child(column)
	var title := Label.new()
	title.text = "PRACTICE TIMING   •   9 to hide"
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Position by best lap • out-lap not counted"
	subtitle.add_theme_font_size_override("font_size",12)
	column.add_child(subtitle)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation",14)
	column.add_child(grid)
	for heading in ["POS", "DRIVER", "BEST", "LAST", "LAPS"]:
		var label := Label.new()
		label.text = heading
		label.add_theme_font_size_override("font_size",13)
		grid.add_child(label)
	for i in range(timing.entries.size()*5):
		var label := Label.new()
		label.add_theme_font_size_override("font_size",14)
		grid.add_child(label)
		rows.append(label)
	refresh()
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_9:
		visible = not visible
		refresh()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_9 and event.physical_keycode == 0:
		visible = not visible
		refresh()

func _process(delta: float) -> void:
	refresh_time += delta
	if visible and refresh_time >= .2:
		refresh_time = 0
		refresh()

func refresh() -> void:
	var sorted: Array = timing.standings()
	for i in range(sorted.size()):
		var entry: Dictionary = sorted[i]
		var values := [str(i+1),entry.name,timing.format_lap(entry.best),timing.format_lap(entry.last),str(entry.laps)]
		for cell in range(5):
			rows[i*5+cell].text = values[cell]
			rows[i*5+cell].modulate = Color(1,.9,.5) if entry.name == "Player" else Color.WHITE
