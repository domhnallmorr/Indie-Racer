extends RefCounted
## Validated season entries resolve reusable, independently composed car specs.
const Physics = preload("res://game/vehicle/physics_config.gd")
const RATINGS = ["cornering", "braking", "throttle", "consistency"]
var data: Dictionary = {}
var entries: Array[Dictionary] = []
var errors: Array[String] = []

static func content_path(value: Variant) -> bool:
	return value is String and value.begins_with("res://content/") and not ".." in value and not "\\" in value

func read_json(path: String) -> Dictionary:
	if not content_path(path) or not FileAccess.file_exists(path):
		errors.append("Missing content file: "+path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema_version") != 1:
		errors.append("Invalid JSON/schema: "+path)
		return {}
	return parsed

func load_roster(path: String) -> bool:
	errors.clear()
	entries.clear()
	data = read_json(path)
	if not data.get("id") is String or not data.get("display_name") is String or not data.get("entries") is Array or data.get("entries", []).is_empty():
		errors.append("Roster needs id, display_name and entries")
		return false
	var ids := {}
	for source in data.entries:
		if not source is Dictionary:
			errors.append("Roster entry must be an object")
			continue
		var entry: Dictionary = source.duplicate(true)
		var valid := true
		for key in ["id", "driver_name", "number", "team", "car_spec", "colour"]:
			if not entry.get(key) is String or entry.get(key, "").is_empty():
				errors.append("Entry missing "+key)
				valid = false
		if not valid:
			continue
		if not entry.id.is_valid_identifier() or ids.has(entry.id) or not Color.html_is_valid(entry.colour):
			errors.append("Invalid/duplicate entry id or colour: "+entry.id)
			continue
		ids[entry.id] = true
		if entry.has("livery"):
			if not content_path(entry.livery) or not ResourceLoader.exists(entry.livery, "Texture2D"):
				errors.append("Invalid livery texture: "+entry.id)
				continue
		var ratings = entry.get("ratings", {})
		if not ratings is Dictionary:
			ratings = {}
		for key in RATINGS:
			var span = ratings.get(key)
			if not span is Array or span.size() != 2:
				valid = false
				continue
			for value in span:
				if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > 100:
					valid = false
			if valid and span[0] > span[1]:
				valid = false
		if not valid:
			errors.append("Ratings must be ordered [min,max] in 0..100: "+entry.id)
			continue
		var spec := read_json(entry.car_spec)
		if not content_path(spec.get("scene")) or not spec.get("components") is Dictionary or not spec.get("ai_class") is String:
			errors.append("Invalid car specification: "+entry.car_spec)
			continue
		for section in Physics.NUMERIC:
			if not content_path(spec.components.get(section)):
				valid = false
		if not valid or not ResourceLoader.exists(spec.scene, "PackedScene"):
			errors.append("Invalid scene/component reference: "+entry.car_spec)
			continue
		var prototype = load(spec.scene).instantiate()
		var compatible: bool = prototype is CharacterBody3D and prototype.has_node("Visual")
		prototype.free()
		if not compatible:
			errors.append("Car scene requires CharacterBody3D with Visual: "+spec.scene)
			continue
		var physics = Physics.new()
		if not physics.load_components(spec.components):
			errors.append_array(physics.errors)
			continue
		entry["spec"] = spec
		entries.append(entry)
	if data.has("race_grid"):
		var grid = data.race_grid
		var grid_ids := {}
		if not grid is Array or grid.size() != entries.size():
			errors.append("race_grid must list every entry exactly once")
		else:
			for id in grid:
				if not id is String or not ids.has(id) or grid_ids.has(id):
					errors.append("race_grid contains an invalid or duplicate entry")
					break
				grid_ids[id] = true
	return errors.is_empty()

func race_entries() -> Array[Dictionary]:
	if not data.get("race_grid") is Array:
		return entries
	var by_id := {}
	for entry in entries:
		by_id[entry.id] = entry
	var ordered: Array[Dictionary] = []
	for id in data.race_grid:
		ordered.append(by_id[id])
	return ordered

func sample(entry: Dictionary, session_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(session_seed)+":"+data.id+":"+entry.id)
	var result := {}
	for key in RATINGS:
		result[key] = rng.randf_range(entry.ratings[key][0],entry.ratings[key][1])
	result["variation_seed"] = rng.randi()
	return result

static func discover() -> Array[String]:
	var result: Array[String] = []
	for folder in DirAccess.get_directories_at("res://content/rosters"):
		var path := "res://content/rosters/"+folder+"/manifest.json"
		if FileAccess.file_exists(path):
			result.append(path)
	result.sort()
	return result
