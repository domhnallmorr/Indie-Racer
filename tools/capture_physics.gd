extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.get_node("HUD/RaceUI").open_page("diagnostics")
	for unused in range(60):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/player_physics.png")
	quit()
