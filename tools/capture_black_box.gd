extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.set_meta("roster_selection", {"file": "res://content/rosters/icr2_test/manifest.json", "seed": 42})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.get_node("DisplayCar/Cockpit").activate()
	var panel = main.get_node("HUD/BlackBox")
	DirAccess.make_dir_recursive_absolute("res://builds/ui")
	for index in range(3):
		panel.select_page(index)
		for unused in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/ui/black_box_%d.png" % index)
	quit()
