extends PanelContainer
## Always-on driving information; switching pages never captures driving input.
const AMBER := Color(1.0, 0.76, 0.16)
const MUTED := Color(0.65, 0.68, 0.71)
const PAGE_NAMES := ["Lap Timing", "Standings", "Fuel"]
var practice: Node
var active_page := 0
var title: Label
var status: Label
var footer: Label
var pages: Array[Control] = []
var tabs: Array[Button] = []
var lap_values: Dictionary = {}
var fuel_values: Dictionary = {}
var standing_rows: Array[Array] = []
var refresh_time := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -458
	offset_right = -18
	offset_top = -346
	offset_bottom = -42
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.018, 0.022, 0.82)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	title = _label(column, "Lap Timing", 25, AMBER)
	status = _label(column, "", 13, MUTED)
	var host := Control.new()
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(host)
	for unused in PAGE_NAMES:
		var page := VBoxContainer.new()
		host.add_child(page)
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pages.append(page)
	var lap_grid := GridContainer.new()
	lap_grid.columns = 4
	lap_grid.add_theme_constant_override("h_separation", 12)
	lap_grid.add_theme_constant_override("v_separation", 12)
	pages[0].add_child(lap_grid)
	for key in ["Lap", "Current", "To go", "Last", "Position", "Best"]:
		_label(lap_grid, key + ":", 17, AMBER)
		lap_values[key] = _label(lap_grid, "—", 17)
		lap_values[key].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lap_values[key].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var standings_grid := GridContainer.new()
	standings_grid.columns = 4
	standings_grid.add_theme_constant_override("h_separation", 12)
	standings_grid.add_theme_constant_override("v_separation", 2)
	pages[1].add_child(standings_grid)
	for heading in ["POS", "DRIVER", "BEST", "LAPS"]:
		_label(standings_grid, heading, 12, AMBER)
	for unused in range(5):
		var row: Array = []
		for cell in range(4):
			var label := _label(standings_grid, "", 15)
			if cell == 1:
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				label.custom_minimum_size.x = 140
				label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			row.append(label)
		standing_rows.append(row)
	var fuel_grid := GridContainer.new()
	fuel_grid.columns = 2
	fuel_grid.add_theme_constant_override("v_separation", 6)
	pages[2].add_child(fuel_grid)
	for key in ["Remaining", "Tank capacity", "Use / lap", "Est. laps left", "Pit service"]:
		_label(fuel_grid, key + ":", 16, AMBER).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fuel_values[key] = _label(fuel_grid, "—", 16)
		fuel_values[key].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer = _label(column, "", 12, MUTED)
	var navigation := HBoxContainer.new()
	column.add_child(navigation)
	for i in range(PAGE_NAMES.size()):
		var button := Button.new()
		button.text = "F%d  %s" % [i + 1, PAGE_NAMES[i]]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_color_override("font_pressed_color", AMBER)
		button.pressed.connect(select_page.bind(i))
		navigation.add_child(button)
		tabs.append(button)
	select_page(0)

func _label(parent: Node, value: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func select_page(index: int) -> void:
	active_page = posmod(index, PAGE_NAMES.size())
	title.text = PAGE_NAMES[active_page]
	for i in range(pages.size()):
		pages[i].visible = i == active_page
		tabs[i].set_pressed_no_signal(i == active_page)
	refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if key in [KEY_F1, KEY_F2, KEY_F3]:
		select_page(key - KEY_F1)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	refresh_time += delta
	if visible and refresh_time >= 0.1:
		refresh_time = 0.0
		refresh()

func refresh() -> void:
	var timing = practice.lap_timing
	var session = practice.session
	var state = practice.player_state
	var racing: bool = session.session_type == session.SessionType.RACE
	var sorted: Array = timing.track_order() if racing else timing.standings()
	var entry: Dictionary = {}
	var player_index := -1
	for i in range(sorted.size()):
		if sorted[i].car == practice.player:
			entry = sorted[i]
			player_index = i
			break
	if entry.is_empty():
		return
	var finished: bool = session.status == session.Status.FINISHED
	var formation: bool = session.status == session.Status.FORMATION
	status.text = ("RACE  •  %d laps" % session.race_laps) if racing else "PRACTICE  •  Remaining: " + session.clock_text()
	if formation:
		status.text += "  •  Formation"
	elif finished:
		status.text += "  •  Finished"
	lap_values["Lap"].text = str(mini(entry.laps + 1, session.race_laps)) if racing else (str(entry.laps + 1) if entry.armed else "OUT")
	if formation:
		lap_values["Lap"].text = "—"
	lap_values["To go"].text = ("0" if finished else str(maxi(0, session.race_laps - entry.laps))) if racing else "—"
	lap_values["Position"].text = "%d / %d" % [player_index + 1, sorted.size()]
	lap_values["Current"].text = timing.format_lap(maxf(0.0, timing.clock - entry.started)) if entry.armed else "--:--.---"
	lap_values["Last"].text = timing.format_lap(entry.last)
	lap_values["Best"].text = timing.format_lap(entry.best)
	# Keep the player's row and nearby competitors visible in a full field.
	var first := clampi(player_index - 2, 0, maxi(0, sorted.size() - standing_rows.size()))
	for row_index in range(standing_rows.size()):
		var index := first + row_index
		var values := ["", "", "", ""]
		if index < sorted.size():
			var driver: Dictionary = sorted[index]
			values = [str(index + 1), str(driver.name), timing.format_lap(driver.best), str(driver.laps)]
			if driver.get("retired",false):
				values[2] = "OUT"
		for cell in range(4):
			standing_rows[row_index][cell].text = values[cell]
			standing_rows[row_index][cell].modulate = AMBER if index == player_index else Color.WHITE
	var laps_left: float = state.fuel_gal / state.fuel_per_lap_gal if state.fuel_per_lap_gal > 0.0 else -1.0
	fuel_values["Remaining"].text = "%.2f gal / %.1f L" % [state.fuel_gal, state.fuel_litres()]
	fuel_values["Tank capacity"].text = "%.1f gal" % state.fuel_capacity_gal
	fuel_values["Use / lap"].text = "%.2f gal" % state.fuel_per_lap_gal
	fuel_values["Est. laps left"].text = "%.1f" % laps_left if laps_left >= 0.0 else "—"
	fuel_values["Remaining"].modulate = Color(1, 0.35, 0.25) if laps_left >= 0.0 and laps_left < 3.0 else Color.WHITE
	fuel_values["Pit service"].text = "Refuelling: %.1f s" % state.service_remaining if state.pit_stall_state == state.StallState.SERVICING else ("In pit lane" if state.is_in_pit_lane else "On track")
	match active_page:
		0: footer.text = "Player  •  " + ("Timed lap" if entry.armed else "Cross start/finish to begin timing")
		1: footer.text = "Positions %d–%d of %d  •  %s" % [first + 1, mini(first + 5, sorted.size()), sorted.size(), "Race order" if racing else "Best lap order"]
		2: footer.text = "US gallons  •  Range estimated from the fuel model"
