extends SceneTree
## Recorded Texas road-edge contact must not be reflected as a wall impact.
const AT := Vector3(-374.544128417969,.345910131931305,146.115844726563)
const HIT := Vector3(-372.428497314453,.345034837722778,149.449768066406)
const HEADING := -2.34161615371704
const SPEED := 103.407333879964
const CURVATURE := .00115152156697733
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("validate")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
func prepare(car) -> void:
	car.reset_dynamics()
	car.rotation = Vector3(0,HEADING,0)
	car.global_position = AT
	# Establish normal floor contact, then restore the recorded pre-impact pose.
	car.velocity = Vector3.DOWN
	car.move_and_slide()
	car.apply_floor_snap()
	car.global_position = AT
	car.speed_mps = SPEED
	car.velocity = Vector3(74.1713638305664,0,72.0532455444336)
func validate() -> void:
	root.set_meta("roster_selection",{"track_id":"texas","file":"res://content/rosters/icr2_test/manifest.json","seed":42})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	for body in main.find_children("*","CollisionObject3D",true,false):
		body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	main.process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frame
	await physics_frame
	var car = main.ai_cars[0]
	var road = main.get_node("MileOval/RacingSurface/RacingSurface_col")
	var wall = main.get_node("MileOval/InnerWall/ConcreteWall/ConcreteWall_col")
	prepare(car)
	check(car._is_drivable_mesh_edge(road,HIT),"Recorded lateral edge must resolve to its shallow road face")
	check(not car._is_drivable_mesh_edge(wall,Vector3(-342.3423,.641017,123.7763)),"An actual inner wall must not qualify as a drivable mesh edge")
	check(not car._is_drivable_mesh_edge(road,HIT+Vector3.UP*.4),"A contact above the road face must not be ignored")
	# Exercise the original failure with the same collision geometry and pose.
	road.set_meta("drivable_surface",false)
	car.reference_step(1.0/60.0,SPEED,CURVATURE)
	var old_speed: float = car.speed_mps
	var old_impacts: bool = not car.wall_impact_this_step.is_empty()
	road.set_meta("drivable_surface",true)
	prepare(car)
	car.reference_step(1.0/60.0,SPEED,CURVATURE)
	check(old_impacts and old_speed < 50.0,"Fixture must reproduce the original spurious wall response")
	check(car.wall_impact_this_step.is_empty() and car.speed_mps > 100,"Verified road edge must retain forward speed without a wall impulse")
	check(car.contact_drift.length() < .001,"Road triangle edge must not create sideways rebound")
	print("TEXAS SURFACE speed_before=",old_speed," speed_after=",car.speed_mps)
	# Second captured seam: the maximum lift sweep reported a false obstacle,
	# but a smaller legal step had clearance. Previously travelled speed became 0.
	car.reset_dynamics()
	var stall_at := Vector3(-397.502380371094,4.71953105926514,-185.677154541016)
	car.rotation = Vector3(0,2.34527325630188,0)
	car.global_position = stall_at
	car.velocity = Vector3.DOWN
	car.move_and_slide()
	car.apply_floor_snap()
	car.global_position = stall_at
	car.speed_mps = 103.484637513329
	car.velocity = Vector3(-73.4347076416016,2.00316405296326,72.8862152099609)
	car.reference_step(1.0/60.0,car.speed_mps,.00456421639092872)
	check(car.speed_mps > 100 and car.global_position.distance_to(stall_at) > 1.5,"Small valid road step must prevent the recorded seam stall")
	check(car.wall_impact_this_step.is_empty(),"Small road step must not produce a wall impact")
	print("TEXAS SEAM speed=",car.speed_mps," distance=",car.global_position.distance_to(stall_at))
	main.free()
	for failure in failures:
		push_error(failure)
	print("TEXAS SURFACE CONTACTS PASSED" if failures.is_empty() else "TEXAS SURFACE CONTACTS FAILED")
	quit(0 if failures.is_empty() else 1)
