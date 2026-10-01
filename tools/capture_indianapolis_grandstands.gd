extends SceneTree
## Render the integrated track and inspect the seating from several sightlines.
var road: Array = []

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.set_meta("roster_selection",{"track_id":"indianapolis","file":"res://content/rosters/irl_2001/manifest.json"})
	var main = load("res://game/main/main.tscn").instantiate()
	main.ai_enabled = false
	root.add_child(main)
	main.get_node("HUD").hide()
	for canvas in main.player.find_children("*","CanvasLayer",true,false):
		canvas.hide()
	var stands: Node3D = main.get_node("MileOval/Grandstands")
	assert(stands.get_child_count() == 16,"Missing Indianapolis stand sections")
	assert(stands.find_children("*","CollisionObject3D",true,false).is_empty(),"Scenery must not add track obstacles")
	var vertices := 0
	for instance in stands.find_children("*","MeshInstance3D",true,false):
		assert(instance.mesh != null)
		for surface in range(instance.mesh.get_surface_count()):
			vertices += instance.mesh.surface_get_array_len(surface)
	print("INDIANAPOLIS GRANDSTANDS: ",stands.get_child_count()," groups, ",vertices/3," triangles; no added collision bodies")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/indianapolis/geometry.json"))
	for strip in data.strips:
		if strip.name == "RacingSurface": road = strip.rows
	var camera: Camera3D = main.get_node("InspectionCamera")
	camera.set_process(false)
	camera.set_physics_process(false)
	camera.near = .5
	camera.far = 6000
	camera.make_current()
	root.msaa_3d = Viewport.MSAA_4X
	for view in [["frontstretch",4000.0,110.0,35.0],
			["south_vista",780.0,130.0,42.0],
			["north_vista",2810.0,160.0,48.0],
			["trackside",110.0,5.0,2.5]]:
		var outer := sample(float(view[1]),0)
		var inner := sample(float(view[1]),-1)
		var inward := (inner-outer).normalized()
		inward.y = 0
		camera.position = outer+inward*float(view[2])+Vector3.UP*float(view[3])
		camera.look_at(outer-inward*24+Vector3.UP*12)
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/indianapolis_stands_"+str(view[0])+".png")
	camera.position = Vector3(140,1400,900)
	camera.look_at(Vector3.ZERO)
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/indianapolis_stands_overview.png")
	main.free()
	quit()

func sample(s: float, column: int) -> Vector3:
	var at := fposmod(s,4023.36)/4023.36*(road.size()-1)
	var i := int(at)
	var a: Array = road[i][column]
	var b: Array = road[i+1][column]
	return Vector3(a[0],a[1],a[2]).lerp(Vector3(b[0],b[1],b[2]),at-i)
