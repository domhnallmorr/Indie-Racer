extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var scene = load("res://game/main/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.get_node("HUD").hide()
	var track = scene.get_node("MileOval")
	var boards = track.get_node("Hoardings")
	assert(boards.get_child_count() == 18)
	for brand in boards.NAMES:
		assert(boards.get_node("Turn2_"+brand+"/Logo").mesh == boards.get_node("Turn3_"+brand+"/Logo").mesh)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.far = 3000
	camera.make_current()
	camera.position = track.global_position + Vector3(170,65,-20)
	camera.look_at(track.global_position + Vector3(280,8,-105))
	await save_view("hoardings_turn2")
	camera.position = track.global_position + Vector3(-130,55,-15)
	camera.look_at(track.global_position + Vector3(-205,8,-125))
	await save_view("hoardings_turn3")
	# A front-on contact sheet checks every logo without perspective occlusion.
	for i in range(9):
		var board = boards.get_node("Turn2_"+boards.NAMES[i]).duplicate()
		scene.add_child(board)
		board.position = Vector3((i%3)*28, 1200-(i/3)*12, 0)
		board.rotation = Vector3.ZERO
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 85
	camera.position = Vector3(28,1196,100)
	camera.look_at(Vector3(28,1196,0))
	await save_view("hoardings_logos")
	print("HOARDINGS CHECK PASSED: 18 boards, matching shared meshes, two track views and logo sheet rendered.")
	quit()
func save_view(label: String) -> void:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/"+label+".png")
