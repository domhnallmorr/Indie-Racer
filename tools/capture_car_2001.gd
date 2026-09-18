extends SceneTree
## Verify the exported asset and render it with Godot's runtime materials.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var car = load("res://content/vehicles/open_wheel/models/open_wheel.glb").instantiate()
	scene.add_child(car)
	var low := Vector3(INF,INF,INF)
	var high := Vector3(-INF,-INF,-INF)
	var paint_count := 0
	for node in car.find_children("*","MeshInstance3D",true,false):
		for s in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(s)
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = node.global_transform * vertex
				low = low.min(p)
				high = high.max(p)
			var mat = node.get_active_material(s)
			if mat.resource_name.begins_with("Livery_"):
				paint_count += 1
				assert(mat.albedo_texture != null,"Paint must retain a replaceable atlas")
				assert(arrays[Mesh.ARRAY_TEX_UV].size() == arrays[Mesh.ARRAY_VERTEX].size())
				for uv in arrays[Mesh.ARRAY_TEX_UV]:
					assert(uv.x >= -0.001 and uv.y >= -0.001 and uv.x <= 1.001 and uv.y <= 1.001)
	var size := high-low
	assert(absf(size.z-5.0)<0.015 and absf(size.x-2.0)<0.015)
	var front = car.find_child("WheelFrontLeft",true,false)
	var rear = car.find_child("WheelRearLeft",true,false)
	assert(front != null and rear != null)
	assert(absf(front.global_position.z-rear.global_position.z+3.0)<0.001)
	assert(paint_count == 14)
	for wing_name in ["FrontWing","RearWing"]:
		var wing = car.find_child(wing_name,true,false)
		assert(wing != null)
		var wing_size: Vector3 = wing.mesh.get_aabb().size
		assert(absf(wing_size.x-(1.62 if wing_name == "FrontWing" else 1.08))<0.002)
		assert(absf(wing_size.z-(0.32 if wing_name == "FrontWing" else 0.36))<0.002)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.10,0.13,0.17)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.8,0.87,1)
	world.environment.ambient_light_energy = 0.65
	scene.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-30,0)
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	scene.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.14,0.17,0.21)
	ground.material_override = ground_mat
	ground.position.y = -0.01
	scene.add_child(ground)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.2
	camera.make_current()
	for view in ["front","rear","side"]:
		camera.position = Vector3(5,3.1,-7) if view == "front" else (Vector3(4,2.3,7) if view == "rear" else Vector3(8,1.3,0))
		camera.look_at(Vector3(0,0.45,0))
		for i in range(6):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/car_2001_"+view+".png")
	# Exercise the future skin path with a diagnostic texture on this instance only.
	var atlas := Image.create(256,256,false,Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(256):
			atlas.set_pixel(x,y,Color(0.08,0.3,0.8) if (x/16+y/16)%2 == 0 else Color.WHITE)
	var texture := ImageTexture.create_from_image(atlas)
	assert(preload("res://content/vehicles/open_wheel/liveries/apply_livery.gd").apply(car,texture) == 14)
	var untouched = load("res://content/vehicles/open_wheel/models/open_wheel.glb").instantiate()
	var original_nose = untouched.find_child("Nose",true,false)
	assert(original_nose.get_active_material(0).albedo_texture != texture,"Livery overrides must stay instance-local")
	untouched.free()
	camera.position = Vector3(5,3.1,-7)
	camera.look_at(Vector3(0,0.45,0))
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/car_2001_uv_check.png")
	print("IR05 OVAL PASSED: bounds ",size,"; 3 m wheelbase; ",paint_count," textured paint panels with valid UVs.")
	quit()
