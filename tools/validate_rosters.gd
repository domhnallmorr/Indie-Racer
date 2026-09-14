extends SceneTree
const Roster = preload("res://game/race/roster_data.gd")
var failures: Array[String] = []
const FIXTURE := "res://content/__roster_validation_fixture.json"

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func validate() -> void:
	var roster = Roster.new()
	check(roster.load_roster("res://content/rosters/club_1996/manifest.json"), "Load season")
	var first: Dictionary = roster.sample(roster.entries[0],1234)
	check(first == roster.sample(roster.entries[0],1234), "Same seed reproduces ratings")
	check(first != roster.sample(roster.entries[0],1235), "New seed changes form")
	var entry: Dictionary = roster.entries[0]
	roster.entries.reverse()
	check(first == roster.sample(entry,1234), "Entry order cannot change driver form")
	for seed_value in range(100):
		var sampled: Dictionary = roster.sample(entry,seed_value)
		for key in Roster.RATINGS:
			check(sampled[key] >= entry.ratings[key][0] and sampled[key] <= entry.ratings[key][1], "Sample bounds")
	check(not Roster.content_path("res://content/../private.json"), "Reject path traversal")
	check(not Roster.content_path("C:/private.json"), "Reject external reference")
	check(not FileAccess.file_exists(FIXTURE), "Fixture path already exists")
	if not failures.is_empty():
		quit(1)
		return
	var malformed: Dictionary = roster.data.duplicate(true)
	malformed.entries[0].ratings.cornering = [100,10]
	var file := FileAccess.open(FIXTURE,FileAccess.WRITE)
	file.store_string(JSON.stringify(malformed))
	file.close()
	check(not roster.load_roster(FIXTURE), "Reject reversed rating range")
	DirAccess.remove_absolute(FIXTURE)
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_file = "res://content/rosters/club_1996/manifest.json"
	main.roster_seed = 1234
	root.add_child(main)
	check(main.ai_cars.size() == 15, "Roster controls grid")
	check(main.ai_cars[0].get_meta("driver_name") == "Sam Blake", "Identity reaches car")
	check(main.ai_cars[0].get_meta("sampled_ratings") == first, "Seed reaches spawned driver")
	check(main.ai_cars[0].physics_components.has("engine"), "Independent components reach vehicle")
	check(main.lap_timing.entries[1].name == "Sam Blake", "Timing uses roster identity")
	var driver = main.ai_cars[0].get_node("Driver")
	check(driver.cornering_utilisation < main.ai_profiles.open_wheel.cornering_utilisation, "Rating changes corner planner")
	check(driver.cornering_utilisation > main.ai_cars[-1].get_node("Driver").cornering_utilisation, "Higher cornering rating retains a pace advantage")
	check(driver.pit_cornering_utilisation < driver.cornering_utilisation and driver.pit_braking_utilisation < driver.braking_utilisation,"Track pace tuning retains separate pit-exit margins")
	var original: float = driver.form
	driver.laps = 1
	driver._physics_process(1.0/60.0)
	check(absf(driver.form-original) <= .002/60.0+.000001, "Form changes smoothly")
	current_scene = main
	var panel = main.get_node("HUD/RosterPanel")
	panel.choices.select(panel.paths.find("res://content/rosters/default/manifest.json"))
	panel.seed_input.value = 5678
	panel.start.pressed.emit()
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.active_seed == 5678, "Selector restarts with requested seed")
	check(current_scene.ai_cars[0].name == "AI_Blue", "Selector changes roster on restart")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("ROSTERS PASSED: discovery, composition, deterministic ranges, validation, spawning, timing and smooth form.")
	quit(0 if failures.is_empty() else 1)
