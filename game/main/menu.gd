extends Control

## Front-end flow for selecting a weekend and launching an existing session.
enum Screen { MAIN, SETUP, WEEKEND, OPTIONS }

const GAME_SCENE := "res://game/main/main.tscn"
const DEFAULT_LAPS := 10
const DEFAULT_ROSTER := "res://content/rosters/irl_2001/manifest.json"
const RosterData = preload("res://game/race/roster_data.gd")

@onready var main_screen: Control = $Center/MainMenu
@onready var setup_screen: Control = $Center/WeekendSetup
@onready var weekend_screen: Control = $Center/WeekendMenu
@onready var track_select: OptionButton = $Center/WeekendSetup/Panel/Margin/Layout/TrackSelect
@onready var roster_select: OptionButton = $Center/WeekendSetup/Panel/Margin/Layout/RosterSelect
@onready var laps_select: SpinBox = $Center/WeekendSetup/Panel/Margin/Layout/LapsSelect
@onready var fuel_select: SpinBox = $Center/WeekendSetup/Panel/Margin/Layout/FuelSelect
@onready var incident_select: OptionButton = $Center/WeekendSetup/Panel/Margin/Layout/IncidentRow/IncidentSelect
@onready var strength_select: HSlider = $Center/WeekendSetup/Panel/Margin/Layout/StrengthRow/StrengthSelect
@onready var strength_label: Label = $Center/WeekendSetup/Panel/Margin/Layout/StrengthRow/StrengthLabel
@onready var race_summary: Label = $Center/WeekendMenu/Panel/Margin/Layout/Summary

var current_screen := Screen.MAIN
var selected_track_name := "Mile Oval"
var options_wheel: CanvasLayer

func _ready() -> void:
	# Release templates reject scene-path overrides; expose the repeatable
	# profiler only through an explicit diagnostic command-line argument.
	if "--profile-indy" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred("res://tools/profile_indy_practice.tscn")
		return
	options_wheel = preload("res://game/input/wheel_input.gd").new()
	options_wheel.menu_mode = true
	options_wheel.close_callback = _on_options_back_pressed
	add_child(options_wheel)
	$Options/Layout/ControlsPanel.menu_wheel = options_wheel
	_populate_tracks()
	laps_select.value = DEFAULT_LAPS
	var selection: Dictionary = get_tree().root.get_meta("roster_selection", {})
	incident_select.add_item("Off")
	incident_select.add_item("AI only")
	incident_select.add_item("Everyone")
	incident_select.select(maxi(0,["off","ai_only","everyone"].find(selection.get("incident_mode","everyone"))))
	strength_select.value_changed.connect(_on_strength_changed)
	strength_select.value = selection.get("ai_strength", 100)
	_on_strength_changed(strength_select.value)
	_populate_rosters(str(selection.get("file", DEFAULT_ROSTER)))
	if get_tree().root.get_meta("return_to_weekend", false):
		get_tree().root.set_meta("return_to_weekend", false)
		laps_select.value = selection.get("race_laps", DEFAULT_LAPS)
		fuel_select.value = selection.get("max_fuel_capacity_gal", 35.0)
		_show_screen(Screen.WEEKEND)
	else:
		_show_screen(Screen.MAIN)

func _populate_tracks() -> void:
	track_select.clear()
	ContentCatalog.refresh()
	var track_ids := ContentCatalog.tracks.keys()
	track_ids.sort()
	for track_id in track_ids:
		var track: Dictionary = ContentCatalog.tracks[track_id]
		if track.get("available", false):
			track_select.add_item(str(track.get("display_name", track_id)))
			track_select.set_item_metadata(track_select.item_count-1,track_id)
	if track_select.item_count == 0:
		track_select.add_item(selected_track_name)
	track_select.select(0)
	var saved_track: String = get_tree().root.get_meta("roster_selection",{}).get("track_id","mile_oval")
	for i in range(track_select.item_count):
		if track_select.get_item_metadata(i) == saved_track:
			track_select.select(i)
	selected_track_name = track_select.get_item_text(track_select.selected)

func _populate_rosters(selected_path: String) -> void:
	roster_select.clear()
	for path in RosterData.discover():
		var data: Dictionary = RosterData.new().read_json(path)
		if data.is_empty():
			continue
		roster_select.add_item(str(data.get("display_name", path.get_base_dir().get_file())))
		roster_select.set_item_metadata(roster_select.item_count - 1, path)
	for path in [DEFAULT_ROSTER, selected_path]:
		for index in range(roster_select.item_count):
			if roster_select.get_item_metadata(index) == path:
				roster_select.select(index)
	roster_select.disabled = roster_select.item_count == 0
	$Center/WeekendSetup/Panel/Margin/Layout/Continue.disabled = roster_select.disabled

func _show_screen(screen: Screen) -> void:
	current_screen = screen
	main_screen.visible = screen == Screen.MAIN
	setup_screen.visible = screen == Screen.SETUP
	weekend_screen.visible = screen == Screen.WEEKEND
	$Options.visible = screen == Screen.OPTIONS
	# The weekend card has its own heading and grows when results are present.
	$Title.visible = screen not in [Screen.OPTIONS, Screen.WEEKEND]
	$Subtitle.visible = screen not in [Screen.OPTIONS, Screen.WEEKEND]
	$Center.offset_top = 160.0 if screen == Screen.SETUP else 48.0
	options_wheel.capture = ""
	if screen == Screen.MAIN:
		$Center/MainMenu/Panel/Margin/Layout/RaceWeekend.grab_focus()
	elif screen == Screen.SETUP:
		track_select.grab_focus()
	elif screen == Screen.OPTIONS:
		$Options/Layout/Back.grab_focus()
	else:
		race_summary.text = "%s  •  %d laps  •  %d gal tank" % [selected_track_name, int(laps_select.value),int(fuel_select.value)]
		if roster_select.selected >= 0:
			race_summary.text += "\n" + roster_select.get_item_text(roster_select.selected)
		race_summary.text += "\nAI strength: %d" % int(strength_select.value)
		race_summary.text += "  •  Incidents: "+incident_select.get_item_text(incident_select.selected)
		var results: Array = get_tree().root.get_meta("roster_selection", {}).get("qualifying_results", [])
		var result_label: Label = $Center/WeekendMenu/Panel/Margin/Layout/ResultsScroll/Results
		result_label.text = "QUALIFYING RESULTS\n"
		for i in range(results.size()):
			var entry: Dictionary = results[i]
			result_label.text += "%d. %s  %s\n" % [i+1, entry.name, preload("res://game/race/lap_timing.gd").format_lap(entry.best)]
		$Center/WeekendMenu/Panel/Margin/Layout/ResultsScroll.visible = not results.is_empty()
		if results.is_empty():
			$Center/WeekendMenu/Panel/Margin/Layout/Practice.grab_focus()
		else:
			$Center/WeekendMenu/Panel/Margin/Layout/Race.grab_focus()

func _on_race_weekend_pressed() -> void:
	_show_screen(Screen.SETUP)

func _on_strength_changed(value: float) -> void:
	strength_label.text = "AI STRENGTH: %d" % int(value)

func _on_options_pressed() -> void:
	_show_screen(Screen.OPTIONS)

func _on_options_back_pressed() -> void:
	_show_screen(Screen.MAIN)
	$Center/MainMenu/Panel/Margin/Layout/Options.grab_focus()

func _on_setup_continue_pressed() -> void:
	if roster_select.selected < 0:
		return
	get_tree().root.set_meta("roster_selection", {"file": roster_select.get_item_metadata(roster_select.selected),
		"track_id":track_select.get_item_metadata(track_select.selected),
		"incident_mode":["off","ai_only","everyone"][incident_select.selected],
		"ai_strength":int(strength_select.value)})
	selected_track_name = track_select.get_item_text(track_select.selected)
	_show_screen(Screen.WEEKEND)

func _on_back_pressed() -> void:
	_show_screen(Screen.MAIN)

func _on_weekend_back_pressed() -> void:
	_show_screen(Screen.SETUP)

func _on_start_session(mode: String) -> void:
	var selection: Dictionary = get_tree().root.get_meta("roster_selection", {}).duplicate(true)
	selection.merge({
		"file": roster_select.get_item_metadata(roster_select.selected),
		"track_id":track_select.get_item_metadata(track_select.selected),
		"session_mode": mode,
		"race_laps": int(laps_select.value),
		"max_fuel_capacity_gal": float(fuel_select.value),
		"ai_strength": int(strength_select.value),
		"incident_mode": ["off","ai_only","everyone"][incident_select.selected],
	}, true)
	if mode == "qualifying":
		selection.erase("qualifying_grid")
		selection.erase("qualifying_results")
	get_tree().root.set_meta("roster_selection", selection)
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_practice_pressed() -> void:
	_on_start_session("practice")

func _on_private_testing_pressed() -> void:
	_on_start_session("private_testing")

func _on_qualifying_pressed() -> void:
	_on_start_session("qualifying")

func _on_race_pressed() -> void:
	_on_start_session("race")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and current_screen == Screen.OPTIONS:
		_on_options_back_pressed()
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and current_screen != Screen.MAIN:
		if current_screen == Screen.OPTIONS:
			_on_options_back_pressed()
		else:
			_show_screen(Screen.SETUP if current_screen == Screen.WEEKEND else Screen.MAIN)
		get_viewport().set_input_as_handled()
