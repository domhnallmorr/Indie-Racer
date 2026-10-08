extends Node
## Player preference only; AI and vehicle setup coefficients are unaffected.
signal handling_changed(experimental: bool)
const SETTINGS_PATH := "user://driving_options.cfg"
var experimental_handling := false
var independent_front_rotation := false

func _ready() -> void:
	var saved := ConfigFile.new()
	if saved.load(SETTINGS_PATH) == OK:
		var value = saved.get_value("driving", "experimental_handling", false)
		if value is bool:
			experimental_handling = value
		var front_value = saved.get_value("driving", "independent_front_rotation", false)
		if front_value is bool:
			independent_front_rotation = experimental_handling and front_value

func set_experimental_handling(enabled: bool, free_front: bool = false) -> Error:
	var saved := ConfigFile.new()
	saved.set_value("driving", "experimental_handling", enabled)
	saved.set_value("driving", "independent_front_rotation", enabled and free_front)
	var error := saved.save(SETTINGS_PATH)
	if error != OK:
		return error
	experimental_handling = enabled
	independent_front_rotation = enabled and free_front
	handling_changed.emit(enabled)
	return OK
