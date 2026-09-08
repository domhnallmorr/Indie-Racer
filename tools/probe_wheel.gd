extends SceneTree
func _initialize() -> void:
	call_deferred("probe")
func probe() -> void:
	await create_timer(2).timeout
	for device in Input.get_connected_joypads():
		print("WHEEL DEVICE ",device," name=",Input.get_joy_name(device)," guid=",Input.get_joy_guid(device)," info=",Input.get_joy_info(device))
	print("DEVICE COUNT ",Input.get_connected_joypads().size())
	quit()
