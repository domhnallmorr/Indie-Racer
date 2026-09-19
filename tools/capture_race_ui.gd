extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_file = "res://content/rosters/club_1996/manifest.json"
	main.roster_seed = 1234
	root.add_child(main)
	await process_frame
	var ui = main.get_node("HUD/RaceUI")
	DirAccess.make_dir_recursive_absolute("res://builds/ui")
	for page_name in ["session","timing","controls","diagnostics"]:
		ui.open_page(page_name)
		for unused in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/ui/"+page_name+".png")
	quit()
