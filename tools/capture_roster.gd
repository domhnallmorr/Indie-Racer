extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_file = "res://content/rosters/club_1996/manifest.json"
	main.roster_seed = 1234
	root.add_child(main)
	main.get_node("HUD/RaceUI").open_page("session")
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://builds")
	root.get_texture().get_image().save_png("res://builds/roster_panel.png")
	quit()
