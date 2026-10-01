extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	root.set_meta("roster_selection",{"session_mode":"race","race_laps":60,"file":"res://content/rosters/icr2_test/manifest.json","seed":1234})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	for body in main.find_children("*","CollisionObject3D",true,false):
		body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	await physics_frame
	main.session.show_green()
	var driver = main.ai_cars[0].get_node("Driver")
	driver.index = 120
	var tangent: Vector3 = (driver.race[121]-driver.race[120]).normalized()
	driver.car.global_transform = driver.car.track.global_transform*Transform3D(Basis.looking_at(tangent),driver.race[120])
	driver.car.speed_mps = 0.0
	driver.race_plan.fail(driver)
	var effect = driver.race_plan.recovery_visual
	check(is_instance_valid(effect),"Engine failure creates visual recovery")
	for tick in range(20*60):
		driver.race_plan.update(driver,1.0/60.0)
	check(driver.race_plan.recovered,"Simulation still recovers after existing dwell")
	check(effect.stranded != null and not driver.car.get_node("Visual").visible,"Roadside visual retained without duplicate at pit box")
	check(effect.find_children("*","CollisionObject3D",true,false).is_empty(),"Recovery has no collision bodies")
	main.pace_car.phase = main.pace_car.Phase.CAUTION
	main.pace_car.caution_distance = main.race_control.length*.99
	effect._physics_process(.016)
	check(effect.pickup == null,"No truck on first caution lap")
	main.pace_car.caution_distance = main.race_control.length*1.01
	effect._physics_process(.016)
	check(effect.stage == effect.Stage.SAFETY and effect.pickup != null,"Safety pickup arrives on lap two")
	var pickup_local: Vector3 = effect.incident_pose.affine_inverse()*effect.pickup.global_position
	check(pickup_local.z > 7.5 and pickup_local.x < -1.5,"Pickup parks behind car toward infield")
	check(effect.crew.get_child_count() == 2,"Two marshals attend the car")
	if "--capture" in OS.get_cmdline_user_args():
		await capture(main,effect,"recovery_safety.png")
	# A second incident/redeployment must not rewind the cosmetic clock.
	var distance_before: float = effect.caution_metres
	main.pace_car.caution_distance = 0.0
	effect._physics_process(.016)
	check(effect.caution_metres >= distance_before,"Redeployment does not rewind recovery")
	effect.stage_seconds = 12.0
	main.pace_car.caution_distance = main.race_control.length*1.02
	effect._physics_process(.016)
	check(effect.stage == effect.Stage.LOADING and effect.flatbed != null,"Flatbed arrives on lap three")
	effect.stage_seconds = effect.LOAD_SECONDS
	effect._physics_process(.016)
	check(effect.stage == effect.Stage.TOWING and effect.stranded.get_parent() == effect.flatbed,"Retired car loaded on deck")
	check(effect.stranded.position.distance_to(Vector3(0,1.08,1.55)) < .01,"Car sits on flatbed")
	check(effect.tow_path.point_count > 50,"Tow follows circuit and pit approach")
	for i in range(effect.tow_path.point_count):
		var point: Vector3 = driver.car.track.to_local(effect.tow_path.get_point_position(i))
		var half_straight := (1609.344-2.0*PI*125.0)/4.0
		var lateral := Vector2(point.x-clampf(point.x,-half_straight,half_straight),point.z).length()-125.0
		check(lateral < -11.5,"Tow keeps truck width below white line")
	check(effect.find_children("*","CollisionObject3D",true,false).is_empty(),"Trucks and marshals remain non-colliding")
	if "--capture" in OS.get_cmdline_user_args():
		await capture(main,effect,"recovery_flatbed.png")
	main.session.finish_race()
	for tick in range(60*240):
		effect._physics_process(1.0/60.0)
		if effect.stage == effect.Stage.DONE:
			break
	check(effect.stage == effect.Stage.DONE and driver.car.get_node("Visual").visible,"Tow finishes after chequered flag and restores pit-box visual")
	check(driver.car.global_transform.is_equal_approx(driver.pit_box_pose),"Visual sequence leaves actual car at assigned box")
	check(main.race_control.caution_count == 1,"Visual sequence creates no extra caution")
	# A short caution still progresses even when pace distance stops advancing.
	var second = main.ai_cars[1].get_node("Driver")
	main.session.status = main.session.Status.RUNNING
	second.race_plan.fail(second)
	var short_effect = second.race_plan.recovery_visual
	for tick in range(20*60):
		second.race_plan.update(second,1.0/60.0)
	main.session.finish_race()
	for tick in range(60*450):
		short_effect._physics_process(1.0/60.0)
		if short_effect.stage == short_effect.Stage.DONE:
			break
	check(short_effect.stage == short_effect.Stage.DONE,"Short caution cannot leave recovery visuals stranded")
	print("RECOVERY VISUALS ","PASSED" if failures.is_empty() else failures)
	main.free()
	quit(0 if failures.is_empty() else 1)

func capture(main: Node, effect: Node3D, filename: String) -> void:
	main.get_node("HUD").hide()
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.fov = 55
	camera.global_position = effect.incident_pose*Vector3(-17,10,18)
	camera.look_at(effect.incident_pose.origin+Vector3(0,1,0))
	camera.make_current()
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/"+filename)
	camera.queue_free()
