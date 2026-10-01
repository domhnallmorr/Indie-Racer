extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var car = load("res://content/vehicles/open_wheel/scenes/vehicle.tscn").instantiate()
	root.add_child(car)
	car.process_mode = Node.PROCESS_MODE_DISABLED
	var visuals = car.get_node("WheelVisuals")
	assert(visuals.wheels.size() == 4)
	for wheel in visuals.wheels:
		assert(wheel.node.has_node("FirestoneInner"))
		assert(wheel.node.has_node("FirestoneOuter"))
		assert(is_equal_approx(wheel.radius, .327))
	var first = visuals.wheels[0]
	var original: Transform3D = first.node.transform
	car.speed_mps = .327
	visuals._process(.5)
	assert(first.node.basis.is_equal_approx(original.basis * Basis(Vector3.RIGHT,-.5)))
	assert(first.node.position.is_equal_approx(original.origin))
	car.speed_mps = 0
	var stopped: Basis = first.node.basis
	visuals._process(1)
	assert(first.node.basis.is_equal_approx(stopped))
	car.speed_mps = -.327
	visuals._process(.5)
	assert(first.node.basis.is_equal_approx(original.basis))
	visuals.advance_distance(TAU * .327)
	assert(first.node.basis.is_equal_approx(original.basis))
	print("WHEEL VISUALS PASSED: four hubs, eight sidewalls, speed-linked forward/reverse rotation, stationary stop, full revolution.")
	if DisplayServer.get_name() == "headless":
		quit()
		return
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("68737a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .65
	root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-30,0)
	root.add_child(light)
	var camera := Camera3D.new()
	camera.near = .01
	root.add_child(camera)
	camera.make_current()
	camera.position = Vector3(-.22,.56,-1.7)
	camera.look_at(Vector3(-.715,.327,-1.343))
	await save_view("tyre_inner_firestone")
	camera.position = Vector3(-3.2,1.6,-4.0)
	camera.look_at(Vector3(0,.4,0))
	await save_view("tyre_branding_car")
	visuals.advance_distance(.327 * PI / 2)
	await save_view("tyre_branding_rotated")
	quit()

func save_view(label: String) -> void:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/" + label + ".png")
