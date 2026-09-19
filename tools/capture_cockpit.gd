extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var preview = load("res://game/main/main.tscn").instantiate()
	root.add_child(preview)
	for i in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/cockpit_godot.png")
	var cockpit = preview.get_node("DisplayCar/Cockpit")
	var inspection = preview.get_node("InspectionCamera")
	assert(cockpit.camera.current)
	assert(cockpit.mirror_views.size() == 1)
	assert(cockpit.virtual_mirror.visible)
	assert(cockpit.virtual_mirror.get_child(0).flip_h)
	for mesh in cockpit.interior.find_children("Mirror*", "MeshInstance3D", true, false):
		assert(not mesh.visible)
	for key in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		cockpit._unhandled_input(event)
		inspection._unhandled_input(event)
		assert(cockpit.camera.current == (key == KEY_5))
		assert(inspection.current == (key != KEY_5))
		assert(cockpit.virtual_mirror.visible == (key == KEY_5))
		for mirror in cockpit.mirror_views:
			assert(mirror.render_target_update_mode == (SubViewport.UPDATE_ALWAYS if key == KEY_5 else SubViewport.UPDATE_DISABLED))
	print("COCKPIT CHECK PASSED: rendered frame, five view switches, mirror update states.")
	quit()
