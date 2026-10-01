extends Node3D
## Cosmetic recovery only: no bodies, timing entries, or race-control decisions.
const TRUCK = preload("res://content/vehicles/safety_crew/recovery_truck.gd")
const PICKUP_LAP := 2
const FLATBED_LAP := 3
const LOAD_SECONDS := 10.0
enum Stage { WAITING, SAFETY, LOADING, TOWING, DONE }
var stage := Stage.WAITING
var driver
var control
var pace
var original: Node3D
var stranded: Node3D
var pickup: Node3D
var flatbed: Node3D
var crew: Node3D
var incident_pose := Transform3D.IDENTITY
var caution_metres := 0.0
var last_pace_distance := 0.0
var caution_number := 0
var stage_seconds := 0.0
var tow_path := Curve3D.new()
var tow_progress := 0.0
var load_start := Transform3D.IDENTITY

func configure(owner_driver) -> void:
	driver = owner_driver
	control = driver.practice_session.race_control
	pace = control.main.pace_car
	last_pace_distance = pace.caution_distance
	caution_number = control.caution_count

func handoff() -> void:
	# Snapshot only the render tree before the simulation recovers the real car.
	original = driver.car.get_node("Visual")
	incident_pose = driver.car.global_transform
	# A nearly stationary pull-over can leave the car pointing sideways. Park
	# response vehicles along the circuit, not along that final lateral motion.
	var at := fposmod(driver.race_plan.distance,driver.race_length_m)
	var point: Vector3 = driver._sample_path(driver.race,driver.race_distances,at)
	var ahead: Vector3 = driver._sample_path(driver.race,driver.race_distances,fposmod(at+2.0,driver.race_length_m))
	var forward: Vector3 = driver.car.track.global_basis*(ahead-point)
	forward.y = 0.0
	incident_pose.basis = Basis.looking_at(forward.normalized())
	stranded = original.duplicate(0) as Node3D
	add_child(stranded)
	stranded.global_transform = original.global_transform
	original.hide()

func _physics_process(delta: float) -> void:
	if stage == Stage.DONE:
		return
	if control.active() and control.caution_count == caution_number and pace.phase in [pace.Phase.DEPLOYING,pace.Phase.CAUTION]:
		# Restart cancellation can reset the pace-car distance; never rewind.
		caution_metres += maxf(0.0,pace.caution_distance-last_pace_distance)
		last_pace_distance = pace.caution_distance
	else:
		# Short cautions / the chequered flag must not strand the visual forever.
		caution_metres += driver.car.track_data.pace_speed_kph/3.6*delta
	if stranded == null:
		return
	var lap := 1+int(caution_metres/maxf(control.length,1.0))
	if stage == Stage.WAITING and lap >= PICKUP_LAP:
		pickup = _truck(false,incident_pose*Vector3(-2.0,0,8.0))
		_add_crew()
		stage = Stage.SAFETY
		stage_seconds = 0.0
	elif stage == Stage.SAFETY and lap >= FLATBED_LAP and stage_seconds >= 8.0:
		flatbed = _truck(true,incident_pose*Vector3(-2.0,0,-7.0))
		load_start = stranded.global_transform
		crew.hide()
		stage = Stage.LOADING
		stage_seconds = 0.0
	elif stage == Stage.LOADING:
		var target := flatbed.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,1.08,1.55))
		stranded.global_transform = load_start.interpolate_with(target,smoothstep(0.0,LOAD_SECONDS,stage_seconds))
		if stage_seconds >= LOAD_SECONDS:
			stranded.reparent(flatbed)
			pickup.hide()
			_build_tow_path()
			stage = Stage.TOWING
			stage_seconds = 0.0
	elif stage == Stage.TOWING:
		tow_progress = minf(tow_path.get_baked_length(),tow_progress+minf(12.0,stage_seconds*2.0)*delta)
		var point := tow_path.sample_baked(tow_progress)
		var ahead := tow_path.sample_baked(minf(tow_progress+1.0,tow_path.get_baked_length()))
		if ahead.distance_squared_to(point) > .00001:
			flatbed.global_basis = Basis.looking_at((ahead-point).normalized())
		flatbed.global_position = _ground(point)
		if tow_progress >= tow_path.get_baked_length():
			finish()
	stage_seconds += delta

func _truck(is_flatbed: bool, at: Vector3) -> Node3D:
	var truck := TRUCK.new()
	truck.flatbed = is_flatbed
	add_child(truck)
	truck.global_transform = Transform3D(incident_pose.basis,_ground(at))
	return truck

func _ground(point: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*6,point-Vector3.UP*12,1)
	var excluded: Array[RID] = [driver.car.get_rid()]
	for rival in driver.rivals:
		excluded.append(rival.get_rid())
	query.exclude = excluded
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		point.y = hit.position.y+.025
	return point

func _add_crew() -> void:
	crew = Node3D.new()
	add_child(crew)
	for z in [-.4,1.4]:
		var person := Node3D.new()
		crew.add_child(person)
		person.global_transform = Transform3D(incident_pose.basis,_ground(incident_pose*Vector3(-1.65,0,z)))
		# Compact marshals in high-visibility coveralls and white helmets.
		for part in [[Vector3(0,1.08,0),Vector3(.48,.62,.3),"eb741c"],
			[Vector3(-.14,.43,0),Vector3(.18,.75,.22),"293c49"],
			[Vector3(.14,.43,0),Vector3(.18,.75,.22),"293c49"],
			[Vector3(0,1.57,0),Vector3(.3,.3,.3),"e8e7da"],
			[Vector3(0,1.12,-.16),Vector3(.49,.1,.025),"ecee9b"],
			[Vector3(-.32,1.07,0),Vector3(.16,.55,.2),"eb741c"],
			[Vector3(.32,1.07,0),Vector3(.16,.55,.2),"eb741c"]]:
			var mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = part[1]
			mesh.mesh = box
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(part[2])
			mesh.material_override = mat
			mesh.position = part[0]
			person.add_child(mesh)

func _build_tow_path() -> void:
	var track: Node3D = driver.car.track
	var start := track.to_local(flatbed.global_position)
	var nearest := 0
	for i in range(driver.race.size()):
		if start.distance_squared_to(driver._inside_return_point(i)) < start.distance_squared_to(driver._inside_return_point(nearest)):
			nearest = i
	tow_path.add_point(flatbed.global_position)
	var cursor: int = (nearest+1)%driver.race.size()
	while cursor != (driver.pit_approach_join_index+1)%driver.race.size():
		tow_path.add_point(track.to_global(driver._inside_return_point(cursor)))
		cursor = (cursor+1)%driver.race.size()
	var pit: PackedVector3Array = driver.car.track_data.pit_path
	var a := tow_path.get_point_position(tow_path.point_count-1)
	var b := track.to_global(pit[0])
	var join: int = driver.pit_approach_join_index
	var tangent: Vector3 = track.global_basis*(driver._inside_return_point((join+1)%driver.race.size())-driver._inside_return_point(join)).normalized()
	var end_tangent := track.global_basis*(pit[1]-pit[0]).normalized()
	var span := a.distance_to(b)
	for i in range(1,51):
		var t := i/50.0
		tow_path.add_point((2*t*t*t-3*t*t+1)*a+(t*t*t-2*t*t+t)*tangent*span+(-2*t*t*t+3*t*t)*b+(t*t*t-t*t)*end_tangent*span)
	var box := track.to_local(driver.pit_box_pose.origin)
	for point in pit:
		if point.x > box.x:
			break
		if track.to_global(point).distance_to(tow_path.get_point_position(tow_path.point_count-1)) > .1:
			tow_path.add_point(track.to_global(point))

func finish() -> void:
	stage = Stage.DONE
	if is_instance_valid(original):
		original.show()
	queue_free()

func _exit_tree() -> void:
	if is_instance_valid(original):
		original.show()
