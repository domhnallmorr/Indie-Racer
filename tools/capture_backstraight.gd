extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var scene = load("res://game/main/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.get_node("HUD").hide()
	var track = scene.get_node("MileOval")
	var scenery = track.get_node("BackstraightScenery")
	assert(scenery.get_node("GrassBank").mesh.get_aabb().size.y == 2.0)
	assert(scenery.get_node("PowerPole9").position.z == -146.0)
	var boards = track.get_node("Hoardings")
	var first = boards.get_node("Turn3_FedEx")
	var expected := Vector3(-boards.STRAIGHT/2.0,0,0)+Vector3(cos(PI/2.0+60.0/125.0),0,-sin(PI/2.0+60.0/125.0))*142.0
	assert(first.position.distance_to(expected) < .01)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.far = 3000
	camera.make_current()
	camera.position = track.global_position + Vector3(75,4,-122)
	camera.look_at(track.global_position + Vector3(-25,5,-145))
	await save_view("backstraight_trackside")
	camera.position = track.global_position + Vector3(50,28,-85)
	camera.look_at(track.global_position + Vector3(0,2,-142))
	await save_view("backstraight_detail")
	camera.position = track.global_position + Vector3(-200,100,30)
	camera.look_at(track.global_position + Vector3(-330,4,0))
	await save_view("turn3_hoardings_shifted")
	print("BACKSTRAIGHT CHECK PASSED: bank height, utility setback, 200 m billboard shift, three views rendered.")
	quit()
func save_view(label: String) -> void:
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/"+label+".png")
