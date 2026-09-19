extends SceneTree
## Real body sweeps: rear contact, sideswipe, player/AI and solid barriers.
const DT := 1.0/60.0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func place(car, at: Vector3, motion: Vector3) -> void:
	car.reset_dynamics()
	car.global_position = at
	car.rotation = Vector3.ZERO
	car._receive_contact_velocity(motion)
	if car.get("sim") != null:
		car.sim.front_omega = car.sim.u/car.parameters.values.front_radius_m
		car.sim.rear_omega = car.sim.u/car.parameters.values.rear_radius_m
		car.sim.gear = 5
		car.sim.engine_omega = maxf(car.sim.rear_omega*car.sim.ratio(),2500*TAU/60)

func step(car) -> void:
	if car.has_method("reference_step"):
		car.reference_step(DT,car.speed_mps,0)
	else:
		car.drive_step(DT,0,0,0)

func validate() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_file = "res://content/rosters/icr2_test/manifest.json"
	root.add_child(main)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var cars: Array = [main.ai_cars[0],main.ai_cars[1],main.player]
	for car in cars:
		car.process_mode = Node.PROCESS_MODE_ALWAYS
		car.set_physics_process(false)
		if car.has_node("Driver"):
			car.get_node("Driver").set_physics_process(false)
		# The practice spawn now ghosts pit cars. These scenarios explicitly test
		# racing contacts, so remove inherited pit exceptions after disabling AI.
		for other in cars:
			if other != car:
				car.remove_collision_exception_with(other)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(500,1,500)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	floor_body.position = Vector3(0,99.5,1000)
	for scenario in ["rear_ai","rear_player","player_rear","side_ai","side_player"]:
		for i in range(cars.size()):
			place(cars[i],Vector3(50+i*10,100.02,1100),Vector3.ZERO)
		var first = cars[2] if scenario == "player_rear" else cars[0]
		var second = cars[2] if scenario in ["rear_player","side_player"] else cars[1]
		var side: bool = scenario.begins_with("side")
		place(first,Vector3(-2.1 if side else 0,100.02,1000),Vector3(2 if side else 0,0,-70))
		place(second,Vector3(0,100.02,1000 if side else 995.4),Vector3(0,0,-70 if side else -65))
		var contacts := 0
		var minimum_speed := 1000.0
		var bounced := false
		for tick in range(50):
			await physics_frame
			step(first)
			step(second)
			minimum_speed = minf(minimum_speed,minf(first.speed_mps,second.speed_mps))
			for car in [first,second]:
				for i in range(car.get_slide_collision_count()):
					if car.get_slide_collision(i).get_collider() in [first,second]:
						contacts += 1
			if side:
				bounced = bounced or second.velocity.x > first.velocity.x+.1
			else:
				bounced = bounced or second.speed_mps > first.speed_mps+.1
		print("CONTACT ",scenario," ticks=",contacts," minimum_kph=",minimum_speed*3.6," bounced=",bounced)
		check(contacts > 0,scenario+" must exercise physical contact")
		check(minimum_speed > 55,scenario+" must preserve racing momentum")
		check(bounced,scenario+" must separate after impact")
		check(contacts < 20,scenario+" must not stick together")
	# A real barrier still removes speed rather than passing through it.
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(20,3,1)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	root.add_child(wall)
	wall.position = Vector3(0,101,990)
	for car in cars:
		place(car,Vector3(0,100.02,1000),Vector3(0,0,-25))
		for tick in range(40):
			await physics_frame
			step(car)
		check(car.global_position.z > 992 and absf(car.speed_mps) < 1,"Barrier must stop "+str(car.name))
		place(car,Vector3(50,100.02,1100),Vector3.ZERO)
	main.free()
	floor_body.free()
	wall.free()
	for failure in failures:
		push_error(failure)
	print("CAR CONTACTS PASSED" if failures.is_empty() else "CAR CONTACTS FAILED")
	quit(0 if failures.is_empty() else 1)
