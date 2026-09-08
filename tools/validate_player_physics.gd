extends SceneTree
var failures: Array[String] = []
const DT := 1.0/60

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func place(car: Node3D, position: Vector3, angle: float, speed := 0.0) -> void:
	car.reset_dynamics()
	car.global_transform = car.track.global_transform * Transform3D(Basis(Vector3.UP,angle),position)
	car.sim.u = speed
	car.sim.front_omega = speed/car.parameters.values.front_radius_m
	car.sim.rear_omega = speed/car.parameters.values.rear_radius_m
	car.sim.engine_omega = maxf(car.sim.rear_omega*car.sim.ratio(),2500*TAU/60)

func validate() -> void:
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4
	var main = load("res://game/main/main.tscn").instantiate()
	main.ai_enabled = false
	root.add_child(main)
	var car = main.player
	car.driving_enabled = false
	check(car.physics_ready,"Player loads new physics")
	place(car,Vector3(-60,.025,101),-PI/2)
	for i in range(360):
		await physics_frame
		car.drive_step(DT,1,0,0)
		check(absf(car.speed_mps) <= 80.0/3.6+.01,"Actual pit cap")
	print("PIT speed=%.2f pos=%s rpm=%.0f" % [car.speed_mps*3.6,car.position,car.engine_rpm])
	check(car.track.to_local(car.global_position).x > -10 and car.speed_mps > 18,"Player leaves stall and accelerates")
	check(car.is_on_floor(),"Pit ground contact")
	car.global_position = car.track.to_global(Vector3(193,.03,101))
	for i in range(25):
		await physics_frame
		car.drive_step(DT,1,0,0)
	check(car.track.to_local(car.global_position).x > 195 and car.speed_mps > 80.0/3.6+.2,"Exit releases player limiter")
	place(car,Vector3(0,.025,130),PI,15)
	for i in range(120):
		await physics_frame
		car.drive_step(DT,1,0,0)
	check(car.track.to_local(car.global_position).z < 136 and absf(car.speed_mps) < 1,"Wall stops dynamic player")
	for backwards in [false,true]:
		place(car,Vector3(198,.025,91),0.0 if backwards else PI)
		if backwards:
			car.sim.select_gear(-1)
		var crossed := false
		for i in range(420):
			await physics_frame
			car.drive_step(DT,1,0,0)
			if car.track.to_local(car.global_position).z >= 100:
				crossed = true
				break
		check(crossed,"Grass re-entry, reverse="+str(backwards)+" pos="+str(car.position))
	place(car,Vector3(330,1.9,0),0,35)
	car.sim.gear = 3
	car.sim.engine_omega = car.sim.rear_omega*car.sim.ratio()
	for i in range(90):
		await physics_frame
		car.drive_step(DT,.2,0,.4)
	check(car.is_on_floor() and car.track.to_local(car.global_position).y > .5,"Banked surface support")
	check(car.sim.downforce_n > 1000,"Actual-track aero")
	car.driving_enabled = true
	var event := InputEventKey.new()
	event.keycode = KEY_R
	event.pressed = true
	main._unhandled_input(event)
	check(car.sim.u == 0 and car.sim.v == 0 and car.sim.yaw_rate == 0 and car.sim.gear == 1,"Reset clears dynamic state")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PLAYER PHYSICS PASSED: launch, pit cap/release, walls, forward/reverse surface recovery, banking, reset.")
	quit(0 if failures.is_empty() else 1)
