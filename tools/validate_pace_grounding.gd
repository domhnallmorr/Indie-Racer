extends SceneTree
var failures: Array[String] = []
var excluded: Array[RID] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	root.set_meta("roster_selection",{"session_mode":"race","race_laps":60,"file":"res://content/rosters/icr2_test/manifest.json","seed":42})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	for body in main.find_children("*","CollisionObject3D",true,false):
		body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	for car in [main.player]+main.ai_cars:
		excluded.append(car.get_rid())
	await physics_frame
	var pace = main.pace_car
	var circuit: Curve3D = main.race_control.circuit
	var max_gap := 0.0
	var max_bank := 0.0
	# Moving samples preserve each preceding visual pose through both turns.
	for i in range(int(circuit.get_baked_length()/2.0)):
		pace._place_on(circuit,i*2.0,true)
		max_gap = maxf(max_gap,tyre_gap(pace))
		max_bank = maxf(max_bank,absf(rad_to_deg(pace.model.rotation.z)))
	check(max_bank > 8.5 and max_bank < 9.5,"Model follows nine-degree banking")
	check(max_gap < .035,"All tyres supported through full caution lap")
	print("PACE GROUND caution max tyre gap=",max_gap," m; max bank=",max_bank," deg")
	var route_gap := 0.0
	for i in range(int(pace.route.get_baked_length()/2.0)):
		pace.progress = i*2.0
		pace._place()
		route_gap = maxf(route_gap,tyre_gap(pace))
	check(route_gap < .045,"Formation, pull-away and pit-entry tyres stay grounded")
	print("PACE GROUND formation/return max tyre gap=",route_gap," m")
	pace.phase = pace.Phase.PARKED
	pace.global_transform = pace.track.global_transform*pace.track_data.pace_car_box
	pace._update_visual_grounding()
	check(tyre_gap(pace) < .015 and absf(pace.model.rotation.z) < .01,"Parked car returns to level")
	pace.deploy_caution(main.player,circuit)
	var deploy_gap := 0.0
	for i in range(int(pace.deployment.get_baked_length()/2.0)):
		pace._place_on(pace.deployment,i*2.0,false)
		deploy_gap = maxf(deploy_gap,tyre_gap(pace))
	check(deploy_gap < .045,"Pit exit/deployment stays grounded")
	print("PACE GROUND deployment max tyre gap=",deploy_gap," m")
	# Real traffic above the road must not become the supporting surface.
	var bank_at := circuit.get_closest_offset(Vector3(330.986459,1.58,0))
	pace._place_on(circuit,bank_at,true)
	var expected: Transform3D = pace.model.transform
	main.ai_cars[0].global_transform = pace.global_transform
	await physics_frame
	pace._update_visual_grounding()
	check(pace.model.transform.is_equal_approx(expected),"Grounding ignores racing cars")
	main.ai_cars[0].global_position += Vector3.UP*20
	if "--capture" in OS.get_cmdline_user_args():
		for canvas in main.find_children("*","CanvasLayer",true,false):
			canvas.hide()
		var camera := Camera3D.new()
		main.add_child(camera)
		camera.fov = 45
		camera.global_position = pace.to_global(Vector3(-6,1.6,6))
		camera.look_at(pace.model.global_position+Vector3.UP*.8)
		camera.make_current()
		for frame in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/pace_car_banking.png")
	print("PACE GROUNDING ","PASSED" if failures.is_empty() else failures)
	main.free()
	quit(0 if failures.is_empty() else 1)

func tyre_gap(pace: Node3D) -> float:
	var worst := 0.0
	for contact in pace.model.TYRE_CONTACTS:
		var bottom: Vector3 = pace.model.to_global(contact)
		var query := PhysicsRayQueryParameters3D.create(bottom+Vector3.UP*2,bottom-Vector3.UP*4,1)
		query.exclude = excluded
		var hit := pace.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return INF
		worst = maxf(worst,absf(bottom.y-hit.position.y))
	return worst
