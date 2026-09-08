extends Node
## Route-following driver; supplies inputs to the same controller as the player.
enum Mode { WAITING, PIT_EXIT, RACING }
var mode: Mode = Mode.WAITING
var release_delay := 4.0
var elapsed := 0.0
var car
var race := PackedVector3Array()
var route := PackedVector3Array()
var index := 0
var laps := 0
var desired_speed_kph := 0.0
var max_line_error_m := 0.0
var rivals: Array[Node3D] = []
var straight_speed := 210.0
var corner_speed := 170.0
var exit_speed := 120.0
var pace := 1.0

func configure(vehicle: Node3D, race_data: Dictionary, delay: float) -> void:
	car = vehicle
	release_delay = delay
	straight_speed = race_data.straight_speed_kph
	corner_speed = race_data.corner_speed_kph
	exit_speed = race_data.pit_exit_speed_kph
	for p in race_data.points:
		race.append(Vector3(p[0],p[1],p[2]))
	# Omit duplicate end point; wrap explicitly when racing.
	if race[0].distance_to(race[-1]) < .1:
		race.resize(race.size()-1)
	_build_departure()

func _build_departure() -> void:
	var start: Vector3 = car.track.to_local(car.global_position)
	# Leave the stall gradually towards the travel lane, clear of parked boxes.
	for i in range(21):
		var t := i / 20.0
		var blend := t*t*(3-2*t)
		route.append(Vector3(start.x+36*t,.008,lerpf(start.z,101.0,blend)))
	var pit: PackedVector3Array = car.track_data.pit_path
	var nearest := 0
	for i in range(pit.size()):
		if pit[i].distance_squared_to(route[-1]) < pit[nearest].distance_squared_to(route[-1]):
			nearest = i
	for i in range(nearest+1,pit.size()):
		route.append(pit[i])
	# Extend the existing taper smoothly across the apron to the racing line.
	var end := route[-1]
	for i in range(1,41):
		var t := i/40.0
		var blend := t*t*(3-2*t)
		route.append(Vector3(end.x-80*t,0,lerpf(end.z,-125.0,blend)))

func _physics_process(delta: float) -> void:
	if car == null:
		return
	elapsed += delta
	if mode == Mode.WAITING:
		if elapsed >= release_delay and _departure_clear():
			mode = Mode.PIT_EXIT
		else:
			car.drive_step(delta,0,0,0)
			return
	var position: Vector3 = car.track.to_local(car.global_position)
	_update_index(position)
	var lookahead := clampf(5.0 + absf(car.speed_mps)*.48, 6, 30)
	var target := _ahead(lookahead)
	var world_target: Vector3 = car.track.to_global(target)
	var offset: Vector3 = car.global_basis.inverse() * (world_target-car.global_position)
	offset.y = 0
	var curvature := -2.0*offset.x / maxf(offset.length_squared(),1)
	var lock := lerpf(28.0,3.5,clampf(absf(car.speed_mps)/55.0,0,1))
	var steering := clampf(atan(curvature*car.wheelbase_m)/deg_to_rad(lock),-1,1)
	if mode == Mode.PIT_EXIT:
		desired_speed_kph = 55.0 if index < 21 else exit_speed
		# Yield while approaching the race surface, including traffic from behind.
		if index > route.size()-65 and not _merge_clear():
			desired_speed_kph = 0
	else:
		var bend := absf(_curvature_ahead())
		desired_speed_kph = (corner_speed if bend > .003 else straight_speed)*pace
		max_line_error_m = maxf(max_line_error_m, position.distance_to(_nearest_point(position)))
	car.update_zone_state()
	if car.player_state.is_in_pit_speed_zone:
		desired_speed_kph = minf(desired_speed_kph,car.track_data.speed_limit_kph)
	var target_mps := _traffic_speed(desired_speed_kph/3.6)
	var error: float = target_mps-car.speed_mps
	var throttle := clampf(error*.7 + .19,0,1)
	var brake := clampf(-error*.6,0,1)
	if target_mps < .1 and car.speed_mps < .5:
		car.speed_mps = 0
		throttle = 0
		brake = 0
	# Never request reverse from AI speed control.
	if car.speed_mps <= .15:
		brake = 0
	car.drive_step(delta,throttle,brake,steering)

func _update_index(position: Vector3) -> void:
	var points := race if mode == Mode.RACING else route
	var old := index
	var best := INF
	for step in range(-2,35):
		var candidate := posmod(index+step,points.size()) if mode == Mode.RACING else clampi(index+step,0,points.size()-1)
		var distance := position.distance_squared_to(points[candidate])
		if distance < best:
			best = distance
			old = candidate
	if mode == Mode.RACING and index > race.size()-35 and old < 35:
		laps += 1
	index = old
	if mode == Mode.PIT_EXIT and index >= route.size()-3:
		mode = Mode.RACING
		index = 0
		for i in range(race.size()):
			if position.distance_squared_to(race[i]) < position.distance_squared_to(race[index]):
				index = i

func _ahead(distance: float) -> Vector3:
	var points := race if mode == Mode.RACING else route
	var current := index
	for unused in range(80):
		var next := (current+1)%points.size() if mode == Mode.RACING else mini(current+1,points.size()-1)
		var length := points[current].distance_to(points[next])
		if length >= distance or next == current:
			return points[current].lerp(points[next],clampf(distance/maxf(length,.001),0,1))
		distance -= length
		current = next
	return points[current]

func _curvature_ahead() -> float:
	var a := _ahead(5)
	var b := _ahead(25)
	var c := _ahead(50)
	return (b-a).normalized().cross((c-b).normalized()).length()/25.0

func _nearest_point(position: Vector3) -> Vector3:
	return Geometry3D.get_closest_point_to_segment(position,race[index],race[(index+1)%race.size()])

func _traffic_speed(request: float) -> float:
	for other in rivals:
		if other == car:
			continue
		var relative: Vector3 = car.global_basis.inverse() * (other.global_position-car.global_position)
		var gap := -relative.z
		if gap > 0 and gap < maxf(12,car.speed_mps*2.0) and absf(relative.x) < 2.8:
			request = minf(request,maxf(0,(gap-7)*.6))
	return request

func _departure_clear() -> bool:
	for other in rivals:
		if other == car:
			continue
		var relative: Vector3 = car.global_basis.inverse() * (other.global_position-car.global_position)
		if relative.z < 6 and relative.z > -35 and relative.x > 1.5 and relative.x < 12:
			return false
	return true

func _merge_clear() -> bool:
	var position: Vector3 = car.track.to_local(car.global_position)
	for other in rivals:
		if other == car:
			continue
		var p: Vector3 = car.track.to_local(other.global_position)
		if absf(p.z+125) < 9 and p.x-position.x > -15 and p.x-position.x < 85:
			return false
	return true
