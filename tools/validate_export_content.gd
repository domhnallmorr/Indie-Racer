extends Node
## Run with the exported executable using --headless res://tools/validate_export_content.tscn.

func _ready() -> void:
	call_deferred("verify")

func verify() -> void:
	var roster_script = load("res://game/race/roster_data.gd")
	var valid := true
	var paths: Array = roster_script.discover()
	print("EXPORTED ROSTERS: ", paths.size())
	for path in paths:
		var roster = roster_script.new()
		if not roster.load_roster(path):
			push_error(str(roster.errors))
			valid = false
	get_tree().root.set_meta("roster_selection", {"file": "res://content/rosters/irl_2001/manifest.json", "track_id": "mile_oval", "ai_telemetry": false})
	var practice = load("res://game/main/main.tscn").instantiate()
	get_tree().root.add_child(practice)
	valid = valid and practice.player.physics_ready and practice.roster.errors.is_empty() and not practice.ai_cars.is_empty()
	print("EXPORTED SESSION: player physics = ", practice.player.physics_ready, ", AI cars = ", practice.ai_cars.size(), ", roster errors = ", practice.roster.errors)
	print("EXPORTED CONTENT VALID: ", valid)
	get_tree().quit(0 if valid else 1)
