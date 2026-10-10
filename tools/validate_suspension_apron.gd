extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4
	root.set_meta("roster_selection",{"track_id":"indianapolis","session_mode":"private_testing","seed":123})
	var main = load("res://game/main/main.tscn").instantiate()
	main.ai_enabled = false
	root.add_child(main)
	await process_frame
	var car = main.player
	car.set_physics_process(false)
	car.player_state.pit_stall_state = car.player_state.StallState.NONE
	var terrain := StaticBody3D.new()
	terrain.position.y = 50
	terrain.collision_layer = 1
	terrain.set_meta("drivable_surface",true)
	# Continuous height, discontinuous normals: flat apron / nine-degree bank.
	# The diagonal seam makes the front/rear rays cross at different times.
	var vertices := PackedVector3Array()
	for span in [[-4.0,0.0],[0.0,4.0]]:
		var a := Vector3(span[0]+1.2,maxf(0,span[0])*tan(deg_to_rad(9)),-6)
		var b := Vector3(span[1]+1.2,maxf(0,span[1])*tan(deg_to_rad(9)),-6)
		var c := Vector3(span[0]-1.2,maxf(0,span[0])*tan(deg_to_rad(9)),6)
		var d := Vector3(span[1]-1.2,maxf(0,span[1])*tan(deg_to_rad(9)),6)
		vertices.append_array(PackedVector3Array([a,c,b,b,c,d]))
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(vertices)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	terrain.add_child(collider)
	root.add_child(terrain)
	await physics_frame
	car.reset_dynamics()
	car.global_transform = Transform3D(Basis.IDENTITY,Vector3(1.3,50.3,0))
	car.sim.gear = 0
	for i in range(120):
		await physics_frame
		car.drive_step(1.0/60,0,1,0)
	var peak_frame_step := 0.0
	var peak_wheel_step := 0.0
	var peak_heave := 0.0
	var previous_normal: Vector3 = car.suspension_normal
	var previous_wheels := PackedVector3Array()
	for wheel in car.suspension_wheels: previous_wheels.append(wheel.global_position)
	for i in range(520):
		await physics_frame
		car.global_position.x = 1.3-i*.005
		car.global_position.z = 0
		car.sim.u = 0
		car.sim.v = 0
		car.sim.yaw_rate = 0
		car.drive_step(1.0/60,0,1,0)
		peak_frame_step = maxf(peak_frame_step,rad_to_deg(previous_normal.angle_to(car.suspension_normal)))
		peak_heave = maxf(peak_heave,absf(car.sim.suspension.heave_velocity_mps))
		previous_normal = car.suspension_normal
		for j in range(4):
			peak_wheel_step = maxf(peak_wheel_step,absf(car.suspension_wheels[j].global_position.y-previous_wheels[j].y))
			previous_wheels[j] = car.suspension_wheels[j].global_position
	print("APRON frame_step_deg=",peak_frame_step," wheel_step_m=",peak_wheel_step," heave_mps=",peak_heave)
	if peak_frame_step > .2: failures.append("Continuous apron heights must not jump the shared wheel frame")
	if peak_wheel_step > .006: failures.append("Front/rear wheels follow apron height without droop snaps")
	if peak_heave > .08: failures.append("Slow apron crossing must not cause a heave impulse")
	# Rotate the reference while leaving physical body-up untouched. A change
	# of road/yaw coordinates must preserve that world orientation.
	car.reset_dynamics()
	var peak_road_rate := 0.0
	var initial_up := Vector3.ZERO
	var peak_up_error := 0.0
	for i in range(120):
		terrain.rotation.y = i*.2/60
		car.rotation.y = terrain.rotation.y
		car.global_position = terrain.to_global(Vector3(2,.16+2*tan(deg_to_rad(9)),0))
		await physics_frame
		car._sample_suspension_road(1.0/60)
		var pose := Basis(Vector3.RIGHT,car.sim.suspension.pitch)*Basis(Vector3.BACK,-car.sim.suspension.roll)
		var physical_up: Vector3 = car._suspension_world_road_basis(car.suspension_normal)*pose.y
		if i == 0: initial_up = physical_up
		else: peak_up_error = maxf(peak_up_error,physical_up.distance_to(initial_up))
		if i > 0:
			peak_road_rate = maxf(peak_road_rate,absf(car.sim.suspension.road_pitch_rate))
			peak_road_rate = maxf(peak_road_rate,absf(car.sim.suspension.road_roll_rate))
	print("BANK FRAME constant-bank road_rate_rad_s=",peak_road_rate)
	print("BANK FRAME world_up_error=",peak_up_error)
	if peak_up_error > .0001: failures.append("Road/yaw reference transport must preserve physical body-up")
	car.telemetry.stop()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("APRON PASSED: independent wheel heights, continuous road frame and yaw transport.")
	quit(0 if failures.is_empty() else 1)
