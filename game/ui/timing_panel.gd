extends PanelContainer
var timing: Node
@export var embedded := false
var shell: Control
var rows: Array[Label] = []
var refresh_time := 0.0
var title: Label
var subtitle: Label

func _ready() -> void:
	if not embedded:
		set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		offset_left = -440
		offset_right = -18
		offset_top = 18
	else:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.025,.04,.06,.94)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	add_child(column)
	title = Label.new()
	column.add_child(title)
	subtitle = Label.new()
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
	if not embedded:
		hide()

func _unhandled_input(event: InputEvent) -> void:
	if embedded:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_9:
		_toggle()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_9 and event.physical_keycode == 0:
		_toggle()

func _toggle() -> void:
	visible = not visible
	refresh()

func _process(delta: float) -> void:
	refresh_time += delta
	if visible and refresh_time >= .2:
		refresh_time = 0
		refresh()

func refresh() -> void:
	var racing: bool = timing.session.session_type == timing.session.SessionType.RACE
	title.text = "RACE STANDINGS" if racing else ("QUALIFYING TIMING" if timing.session.session_type == timing.session.SessionType.QUALIFYING else "PRACTICE TIMING")
	subtitle.text = "Position by laps and track progress" if racing else "Position by best lap • out-lap not counted"
	var sorted: Array = timing.standings()
	for i in range(sorted.size()):
		var entry: Dictionary = sorted[i]
		var values := [str(i+1),entry.name,timing.format_lap(entry.best),timing.format_lap(entry.last),str(entry.laps)]
		if entry.get("retired",false):
			values[1] += " — OUT (engine)"
		for cell in range(5):
			rows[i*5+cell].text = values[cell]
			rows[i*5+cell].tooltip_text = str(entry.get("retirement_reason","Retired")) if entry.get("retired",false) else ("Returning to pits — Other" if entry.car.get_meta("withdrawing",false) else ("Fuel strategy: +%d laps per tank" % int(entry.car.get_meta("strategy_extra_laps",0)) if racing else ""))
			rows[i*5+cell].modulate = Color(1,.9,.5) if entry.name == "Player" else Color.WHITE
