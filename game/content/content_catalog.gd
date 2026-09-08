extends Node
## Discovers immediate package folders. Metadata can exist before a scene is built.
## Call refresh() after adding packages during an editor session.

const ROOTS := {
	"track": "res://content/tracks",
	"vehicle": "res://content/vehicles",
}

var tracks: Dictionary = {}
var vehicles: Dictionary = {}


func _ready() -> void:
	refresh()
	print("Content catalog: %d tracks, %d vehicles (including placeholders)." % [tracks.size(), vehicles.size()])


func refresh() -> void:
	tracks = _scan_packages("track")
	vehicles = _scan_packages("vehicle")


func _scan_packages(kind: String) -> Dictionary:
	var found: Dictionary = {}
	var root: String = ROOTS[kind]
	var directory := DirAccess.open(root)
	if directory == null:
		push_warning("Cannot open content directory: " + root)
		return found
	var folders := directory.get_directories()
	folders.sort()
	for folder in folders:
		var package_path := root.path_join(folder)
		var manifest_path := package_path.path_join("manifest.json")
		if not FileAccess.file_exists(manifest_path):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(manifest_path)) != OK:
			push_warning("Invalid JSON in " + manifest_path)
			continue
		if not json.data is Dictionary:
			push_warning("Manifest must be an object: " + manifest_path)
			continue
		var entry: Dictionary = json.data
		if entry.get("schema_version") != 1 or entry.get("type") != kind or entry.get("id") != folder:
			push_warning("Unsupported schema, wrong type, or ID/folder mismatch: " + manifest_path)
			continue
		if not entry.get("display_name") is String or str(entry.get("display_name")).strip_edges().is_empty():
			push_warning("Missing display_name: " + manifest_path)
			continue
		var scene_value = entry.get("scene", "")
		if not scene_value is String:
			push_warning("Scene must be a relative path or empty string: " + manifest_path)
			continue
		var scene: String = scene_value
		if not scene.is_empty():
			if scene.is_absolute_path() or ".." in scene or ":" in scene or "\\" in scene:
				push_warning("Scene must stay inside its package: " + manifest_path)
				continue
			if not ResourceLoader.exists(package_path.path_join(scene), "PackedScene"):
				push_warning("Scene does not exist: " + manifest_path)
				continue
		entry["package_path"] = package_path
		entry["scene_path"] = "" if scene.is_empty() else package_path.path_join(scene)
		entry["available"] = not scene.is_empty()
		found[folder] = entry
	return found
