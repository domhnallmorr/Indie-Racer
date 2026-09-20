extends Node3D
## Reusable formation/caution vehicle. Routes reuse the authored pit lane.
enum Phase { PARKED, LEADING, PULLING_AWAY, PIT_ENTRY, DEPLOYING, CAUTION }
var phase := Phase.PARKED
var clear_of_track := false
var speed_mps := 0.0
var route := Curve3D.new()
var progress := 0.0
var pull_away_distance := 0.0
var pit_distance := 0.0
var leader: Node3D
var track: Node3D
var track_data
var model: Node3D
var caution_circuit: Curve3D
var caution_picked_up := false
var caution_distance := 0.0
var caution_at := 0.0
var deployment := Curve3D.new()
var deployment_at := 0.0
var return_after_deployment := false

func configure(track_node: Node3D, data, pole: Node3D, race: bool) -> void:
	track = track_node
	track_data = data
	leader = pole
	model = preload("res://content/vehicles/pace_car/pace_car_model.gd").new()
	add_child(model)
	global_transform = track.global_transform*data.pace_car_box
	_add_bay_label()
	if not race:
		return
	_build_route()
	phase = Phase.LEADING
	speed_mps = data.pace_speed_kph/3.6
	model.flashing = true
	_place()

func _build_route(from_current: bool = false) -> void:
	route.clear_points()
	progress = 0.0
	pull_away_distance = 0.0
	pit_distance = 0.0
	var paths: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/mile_oval/ai/reference_paths.json"))
	var points: Array = paths.reference_path
	var start := 0
	var nearest_pit := 0
	var start_position: Vector3 = track_data.grid_origin+Vector3(-25,0,0)
	if from_current:
		start_position = track.to_local(global_position)
	var pit: PackedVector3Array = track_data.pit_path
	for i in range(points.size()-1):
		if _point(points[i]).distance_squared_to(start_position) < _point(points[start]).distance_squared_to(start_position):
			start = i
		if _point(points[i]).distance_squared_to(pit[0]) < _point(points[nearest_pit]).distance_squared_to(pit[0]):
			nearest_pit = i
	var join := posmod(nearest_pit-35,points.size()-1)
	var cursor := start
	while true:
		var p := _point(points[cursor])
		route.add_point(p)
		# Early Turn 3: switch off the lights and accelerate away.
		if pull_away_distance == 0.0 and p.x < -float(paths.straight_length_m)/2.0 and p.z < -90.0:
			pull_away_distance = route.get_baked_length()
		if cursor == join:
			break
		cursor = (cursor+1)%(points.size()-1)
	var a := route.get_point_position(route.point_count-1)
	var tangent := (_point(points[(join+1)%(points.size()-1)])-a).normalized()
	var end_tangent := (pit[1]-pit[0]).normalized()
	var span := a.distance_to(pit[0])
	for i in range(1,51):
		var t := i/50.0
		route.add_point((2*t*t*t-3*t*t+1)*a+(t*t*t-2*t*t+t)*tangent*span+(-2*t*t*t+3*t*t)*pit[0]+(t*t*t-t*t)*end_tangent*span)
	pit_distance = route.get_baked_length()
	var box: Vector3 = track_data.pace_car_box.origin
	for p in pit:
		if p.x >= box.x-35.0:
			break
		if p.distance_to(route.get_point_position(route.point_count-1)) > .1:
			route.add_point(p)
	var turn := route.get_point_position(route.point_count-1)
	for i in range(1,31):
		var t := i/30.0
		route.add_point(turn.lerp(box,t)+Vector3(0,0,(box.z-turn.z)*(smoothstep(0.0,1.0,t)-t)))

func _point(p: Array) -> Vector3:
	return Vector3(p[0],p[1]+.025,p[2])

func _physics_process(delta: float) -> void:
	if phase == Phase.PARKED:
		return
	if phase in [Phase.DEPLOYING,Phase.CAUTION]:
		_advance_caution(delta)
		return
	if phase == Phase.LEADING and progress >= pull_away_distance:
		phase = Phase.PULLING_AWAY
		model.flashing = false
	var remaining := route.get_baked_length()-progress
	var target: float = track_data.pace_speed_kph/3.6
	if phase == Phase.LEADING and is_instance_valid(leader):
		# Match the real leader's progress, preserving the gap during launch.
		var leader_progress := route.get_closest_offset(track.to_local(leader.global_position))
		target = clampf(target+(leader_progress+25.0-progress)*.5,0.0,target+4.0)
	elif phase == Phase.PULLING_AWAY:
		target = minf(140.0/3.6,sqrt(pow(track_data.speed_limit_kph/3.6,2)+2*6.0*maxf(0,pit_distance-progress-12)))
	if progress >= pit_distance:
		phase = Phase.PIT_ENTRY
		clear_of_track = true
		target = track_data.speed_limit_kph/3.6
	if remaining < 45.0:
		target = minf(minf(target,8.0),sqrt(2.0*2.5*remaining))
	speed_mps = move_toward(speed_mps,target,(6.0 if speed_mps > target else 3.0)*delta)
	progress = minf(route.get_baked_length(),progress+speed_mps*delta)
	_place()
	if remaining < .08:
		phase = Phase.PARKED
		speed_mps = 0.0
		global_transform = track.global_transform*track_data.pace_car_box

func _place() -> void:
	var p := route.sample_baked(progress)
	var ahead := route.sample_baked(minf(progress+1.0,route.get_baked_length()))
	if ahead.distance_to(p) > .001:
		global_transform = track.global_transform*Transform3D(Basis.looking_at((ahead-p).normalized()),p)

func deploy_caution(pole: Node3D, circuit: Curve3D) -> void:
	leader = pole
	caution_circuit = circuit
	caution_picked_up = false
	caution_distance = 0.0
	return_after_deployment = false
	clear_of_track = false
	model.flashing = true
	if phase in [Phase.CAUTION,Phase.LEADING,Phase.PULLING_AWAY]:
		caution_at = circuit.get_closest_offset(track.to_local(global_position))
		phase = Phase.CAUTION
		return
	# A fresh deployment follows the pit travel lane before merging onto the
	# centre line; the pace car never materialises ahead of the race leader.
	deployment.clear_points()
	deployment_at = 0.0
	var start: Vector3 = track.to_local(global_position)
	deployment.add_point(start)
	var pit: PackedVector3Array = track_data.pit_path
	var nearest := 0
	for i in range(pit.size()):
		if start.distance_squared_to(pit[i]) < start.distance_squared_to(pit[nearest]):
			nearest = i
	for i in range(nearest+1,pit.size()):
		var p := pit[i]
		var distance: float = start.distance_to(p)
		p.z = lerpf(start.z,p.z,smoothstep(0,35,distance))
		deployment.add_point(p+Vector3(0,.025,0))
	var end := deployment.get_point_position(deployment.point_count-1)
	caution_at = fposmod(circuit.get_closest_offset(end)+120.0,circuit.get_baked_length())
	var join := circuit.sample_baked(caution_at)+Vector3(0,.025,0)
	var tangent := (end-deployment.get_point_position(deployment.point_count-2)).normalized()
	var join_tangent := (circuit.sample_baked(fposmod(caution_at+2,circuit.get_baked_length()))-circuit.sample_baked(caution_at)).normalized()
	var span := end.distance_to(join)
	for i in range(1,41):
		var t := i/40.0
		deployment.add_point((2*t*t*t-3*t*t+1)*end+(t*t*t-2*t*t+t)*tangent*span+(-2*t*t*t+3*t*t)*join+(t*t*t-t*t)*join_tangent*span)
	phase = Phase.DEPLOYING

func _advance_caution(delta: float) -> void:
	var pace: float = track_data.pace_speed_kph/3.6
	if phase == Phase.DEPLOYING:
		var remaining := deployment.get_baked_length()-deployment_at
		var target := minf(track_data.speed_limit_kph/3.6,sqrt(2*4.0*maxf(0,remaining)))
		speed_mps = move_toward(speed_mps,target,4.0*delta)
		deployment_at = minf(deployment.get_baked_length(),deployment_at+speed_mps*delta)
		_place_on(deployment,deployment_at,false)
		if remaining < .1:
			phase = Phase.CAUTION
			speed_mps = 0.0
			if return_after_deployment:
				return_from_caution()
		return
	var length := caution_circuit.get_baked_length()
	if not caution_picked_up and is_instance_valid(leader):
		var leader_at := caution_circuit.get_closest_offset(track.to_local(leader.global_position))
		var gap := fposmod(caution_at-leader_at,length)
		if gap <= 100.0:
			caution_picked_up = true
	speed_mps = move_toward(speed_mps,pace if caution_picked_up else 0.0,4.0*delta)
	var travelled := speed_mps*delta
	caution_distance += travelled
	caution_at = fposmod(caution_at+travelled,length)
	_place_on(caution_circuit,caution_at,true)

func _place_on(path: Curve3D, at: float, loop: bool) -> void:
	var p := path.sample_baked(at)
	var next := fposmod(at+1,path.get_baked_length()) if loop else minf(at+1,path.get_baked_length())
	var ahead := path.sample_baked(next)
	if ahead.distance_to(p) > .001:
		global_transform = track.global_transform*Transform3D(Basis.looking_at((ahead-p).normalized()),p+Vector3(0,.025 if loop else 0.0,0))

func return_from_caution() -> void:
	if phase == Phase.PARKED or phase == Phase.PIT_ENTRY:
		return
	if phase == Phase.DEPLOYING:
		# Complete the deployment before taking the normal circuit return route.
		return_after_deployment = true
		model.flashing = false
		return
	_build_route(true)
	phase = Phase.PULLING_AWAY
	model.flashing = false

func _add_bay_label() -> void:
	var label := Label3D.new()
	label.text = "PACE CAR"
	label.font_size = 64
	label.pixel_size = .025
	label.modulate = Color("ffcf42")
	label.rotation_degrees = Vector3(-90,0,0)
	label.position = track_data.pace_car_box.origin+Vector3(0,.035,2.7)
	track.add_child(label)

