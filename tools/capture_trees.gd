extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var scene = load("res://game/main/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.get_node("HUD").hide()
	var track = scene.get_node("MileOval")
	var trees = track.get_node("UrbanTrees")
	print("TREE COUNT: ",trees.placements.size(),"; VARIANTS: ",trees.get_child_count())
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.far = 2000
	camera.near = 2.0
	camera.fov = 48.0
	camera.make_current()
	camera.position = track.global_position+Vector3(0,560,160)
	camera.look_at(track.global_position)
	await save_view("trees_overview")
	# Temporary lineup for reviewing all ten meshes under the game's lighting.
	for i in range(10):
		var tree := MeshInstance3D.new()
		tree.mesh = trees.make_tree(i)
		scene.add_child(tree)
		tree.position = track.global_position+Vector3(-81+i*18,0,223)
	camera.position = track.global_position+Vector3(0,25,358)
	camera.look_at(track.global_position+Vector3(0,9,223))
	camera.fov = 66.0
	await save_view("trees_selection")
	quit()
func save_view(label: String) -> void:
	for i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/"+label+".png")
