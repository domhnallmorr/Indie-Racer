extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.set_meta("roster_selection",{"session_mode":"race","race_laps":60,"file":"res://content/rosters/icr2_test/manifest.json","seed":1234})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	for car in main.ai_cars:
		car.get_node("Driver").set_physics_process(false)
	main.session.show_green()
	var car = main.ai_cars[0]
	var driver = car.get_node("Driver")
	var pull_over := "--pull-over" in OS.get_cmdline_user_args()
	car.speed_mps = 65 if pull_over else 0
	driver.race_plan.fail(driver)
	driver.set_physics_process(pull_over)
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.global_position = car.global_position+Vector3(-8,4,7)
	camera.look_at(car.global_position+Vector3(0,1,0))
	camera.current = true
	for frame in range(780 if pull_over else 150):
		await process_frame
		camera.global_position = car.global_position+Vector3(-8,4,7)
		camera.look_at(car.global_position+Vector3(0,1,0))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/engine_failure_pullover.png" if pull_over else "res://builds/engine_failure.png")
	main.free()
	quit()
