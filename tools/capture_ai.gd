extends SceneTree
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	var event := InputEventKey.new()
	event.keycode = KEY_7
	event.pressed = true
	main.get_node("DisplayCar/Cockpit")._unhandled_input(event)
	main.get_node("InspectionCamera")._unhandled_input(event)
	for i in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/ai_pitboxes.png")
	quit()
