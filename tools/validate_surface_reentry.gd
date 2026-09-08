extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	var car = main.player
	car.driving_enabled = false
	# Exit straight beyond the limiter: grass is -0.1 m, pit pavement +0.008 m.
	for scenario in [
		["forward pit re-entry", Vector3(198,.02,91), PI, false, 100.0, 1],
		["reverse pit re-entry", Vector3(198,.02,91), 0.0, true, 100.0, 1],
		["backstraight apron re-entry", Vector3(0,.02,-104), 0.0, false, -113.0, -1],
	]:
		car.reset_dynamics()
		car.global_transform = car.track.global_transform * Transform3D(Basis(Vector3.UP,scenario[2]),scenario[1])
		if scenario[3]:
			car.sim.select_gear(-1)
		for i in range(12):
			await physics_frame
			car.drive_step(1.0/60.0,0,0,0)
		var reached := false
		for i in range(420):
			await physics_frame
			car.drive_step(1.0/60.0,1,0,0)
			if car.track.to_local(car.global_position).z * scenario[5] >= scenario[4] * scenario[5]:
				reached = true
				break
		if not reached:
			failures.append("%s blocked at %s" % [scenario[0],car.position])
		elif not car.is_on_floor() or car.track.to_local(car.global_position).y < -.02:
			failures.append("%s did not settle on pavement" % scenario[0])
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("SURFACE RE-ENTRY PASSED: forward/reverse grass-to-pit and grass-to-apron.")
	quit(0 if failures.is_empty() else 1)
