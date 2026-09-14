extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var scene = load("res://game/main/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.get_node("HUD").hide()
	var track = scene.get_node("MileOval")
	var stand = track.get_node("MainGrandstand")
	assert(stand.has_node("Roof") and stand.has_node("CommentaryBooths"))
	assert(track.get_node("Grandstands").get_child_count() == 10)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.far = 3000
	camera.make_current()
	camera.position = track.global_position + Vector3(62,3,107)
	camera.look_at(track.global_position + Vector3(62,9,150))
	await save_view("main_grandstand_trackside")
	camera.position = track.global_position + Vector3(-80,55,20)
	camera.look_at(track.global_position + Vector3(62,8,158))
	await save_view("main_grandstand_overview")
	print("MAIN GRANDSTAND CHECK PASSED: canopy, booths, ten separate stands retained; two views rendered.")
	quit()
func save_view(label: String) -> void:
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/"+label+".png")
