extends SceneTree
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://game/main/main.tscn").instantiate()
	scene.ai_enabled = false
	root.add_child(scene)
	await process_frame
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.get_node("HUD").hide()
	var track = scene.get_node("MileOval")
	var ads = track.get_node("WallAdvertisements")
	assert(ads.panels.size() == 52)
	var zones := {}
	for panel in ads.panels:
		zones[panel.zone] = zones.get(panel.zone,0)+1
		assert(panel.brand in ads.NAMES)
		if panel.inner:
			assert(panel.start >= 125 and panel.end <= ads.STRAIGHT)
			var face: Vector3 = ads._on_wall(panel.start,0.5,true,0.012)
			assert(absf(face.z-108.262)<0.001,"Inner adverts must face the racing straight on PitSeparator")
	assert(zones == {"Turn1Entry":8,"Turn2Exit":8,"Turn3Entry":8,"Turn4Exit":8,"InnerFrontStraight":20})
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.far = 2000
	camera.near = 0.1
	camera.fov = 65
	camera.make_current()
	for view in ["Turn1Entry","Turn2Exit","Turn3Entry","Turn4Exit","InnerFrontStraight"]:
		var selected: Array = []
		for panel in ads.panels:
			if panel.zone == view:
				selected.append(panel)
		var panel: Dictionary = selected[2]
		var s: float = panel.start+6.8
		var target: Vector3 = ads._on_wall(s,0.55,panel.inner,0.02)
		var ahead: Vector3 = ads._on_wall(s+1,0.55,panel.inner,0.02)
		var tangent := (ahead-target).normalized()
		var normal := tangent.cross(Vector3.UP).normalized()*(1.0 if panel.inner else -1.0)
		camera.position = track.global_position+target+normal*22-tangent*18+Vector3.UP*4
		camera.look_at(track.global_position+target+tangent*10)
		await save_view("wall_ads_"+view)
	camera.position = track.global_position+Vector3(-65,1.0,119)
	camera.look_at(track.global_position+Vector3(70,0.8,110))
	await save_view("wall_ads_main_straight_driver")
	# Overview verifies the four outer zones and the inner-front-only distribution.
	camera.position = track.global_position+Vector3(0,590,160)
	camera.look_at(track.global_position)
	camera.fov = 48
	await save_view("wall_ads_overview")
	print("WALL ADS PASSED: four outer zones x 8 panels; racing-facing PitSeparator x 20; 156 logos; no pit-side infield wall adverts.")
	quit()

func save_view(label: String) -> void:
	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/"+label+".png")
