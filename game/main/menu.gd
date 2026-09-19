extends Control

## Front-end flow for selecting a weekend and launching an existing session.
enum Screen { MAIN, SETUP, WEEKEND }

const GAME_SCENE := "res://game/main/main.tscn"
const DEFAULT_LAPS := 10

@onready var main_screen: Control = $Center/MainMenu
@onready var setup_screen: Control = $Center/WeekendSetup
@onready var weekend_screen: Control = $Center/WeekendMenu
@onready var track_select: OptionButton = $Center/WeekendSetup/Panel/Margin/Layout/TrackSelect
@onready var laps_select: SpinBox = $Center/WeekendSetup/Panel/Margin/Layout/LapsSelect
@onready var fuel_select: SpinBox = $Center/WeekendSetup/Panel/Margin/Layout/FuelSelect
@onready var race_summary: Label = $Center/WeekendMenu/Panel/Margin/Layout/Summary

var current_screen := Screen.MAIN
var selected_track_name := "Mile Oval"

func _ready() -> void:
	_populate_tracks()
	laps_select.value = DEFAULT_LAPS
	var selection: Dictionary = get_tree().root.get_meta("roster_selection", {})
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
	if track_select.item_count == 0:
		track_select.add_item(selected_track_name)
	track_select.select(0)
	selected_track_name = track_select.get_item_text(0)

func _show_screen(screen: Screen) -> void:
	current_screen = screen
	main_screen.visible = screen == Screen.MAIN
	setup_screen.visible = screen == Screen.SETUP
	weekend_screen.visible = screen == Screen.WEEKEND
	if screen == Screen.MAIN:
		$Center/MainMenu/Panel/Margin/Layout/RaceWeekend.grab_focus()
	elif screen == Screen.SETUP:
		track_select.grab_focus()
	else:
		race_summary.text = "%s  •  %d laps  •  %d gal tank" % [selected_track_name, int(laps_select.value),int(fuel_select.value)]
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

func _on_setup_continue_pressed() -> void:
	get_tree().root.set_meta("roster_selection", {})
	selected_track_name = track_select.get_item_text(track_select.selected)
	_show_screen(Screen.WEEKEND)

func _on_back_pressed() -> void:
	_show_screen(Screen.MAIN)

func _on_weekend_back_pressed() -> void:
	_show_screen(Screen.SETUP)

func _on_start_session(mode: String) -> void:
	var selection: Dictionary = get_tree().root.get_meta("roster_selection", {}).duplicate(true)
	selection.merge({
		"session_mode": mode,
		"race_laps": int(laps_select.value),
		"max_fuel_capacity_gal": float(fuel_select.value),
	}, true)
	if mode == "qualifying":
		selection.erase("qualifying_grid")
		selection.erase("qualifying_results")
	get_tree().root.set_meta("roster_selection", selection)
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_practice_pressed() -> void:
	_on_start_session("practice")

func _on_qualifying_pressed() -> void:
	_on_start_session("qualifying")

func _on_race_pressed() -> void:
	_on_start_session("race")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and current_screen != Screen.MAIN:
		_show_screen(Screen.SETUP if current_screen == Screen.WEEKEND else Screen.MAIN)
		get_viewport().set_input_as_handled()
