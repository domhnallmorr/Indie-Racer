extends Node

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ENTER and event.alt_pressed:
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		_set_windowed()
		get_viewport().set_input_as_handled()

func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		_set_windowed()

func _set_windowed() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
