extends Node
## Route-following driver; supplies inputs to the same controller as the player.
enum Mode { WAITING, PIT_EXIT, RACING, FORMATION, PIT_ENTRY }
var mode: Mode = Mode.WAITING
var practice_cycle := false
var practice_session: Node
var pit_box_pose := Transform3D.IDENTITY
var cycle_rng := RandomNumberGenerator.new()
var stint_laps := 6
var stint_start_laps := 0
var pit_entry_index := 0
var pit_entry_lane_distance := 0.0
var pit_approach_join_index := 0
var completed_stints := 0
var car_ghost := false
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
var route_distances := PackedFloat64Array()
var merge_gate_m := 0.0
var merge_committed := false
var merge_blocker := ""
var route_join_index := 0
var braking_utilisation := 0.8
var cornering_utilisation := 0.92
var pit_cornering_utilisation := 0.92
var pit_braking_utilisation := 0.8
var braking_margin_m := 5.0
var race_length_m := 0.0
var race_distances := PackedFloat64Array()
var surface_normals: Dictionary = {}
var traffic_reason := "clear"
var diagnostic: FileAccess
var log_elapsed := 0.0
var log_flush_elapsed := 0.0
var pending_log_rows := PackedStringArray()
var ratings: Dictionary = {}
var form_rng := RandomNumberGenerator.new()
var form := 1.0
var form_target := 1.0
var form_lap := 0
var cornering_base := 0.92
var braking_base := 0.8
var throttle_response := 1.0
var racecraft = preload("res://game/ai/racecraft.gd").new()
var formation_lane_m := 0.0
var formation_speed_kph := 80.0
var formation_row := 0
const DIAGNOSTIC_HEADER := "time_s,mode,index,x_m,z_m,speed_kph,planned_kph,traffic_target_kph,reason,throttle,brake,steering,gear,rpm,grounded,collisions,line_error_m,racecraft,lane,target_lane,opponent,passes"

func configure_performance(sampled: Dictionary, profile: Dictionary) -> void:
	ratings = sampled.duplicate(true)
	form_rng.seed = int(ratings.variation_seed)
	cornering_base = profile.cornering_utilisation * lerpf(profile.get("minimum_cornering_factor",.8),1.0,ratings.cornering/100.0)
	braking_base = profile.braking_utilisation * lerpf(.65,1.0,ratings.braking/100.0)
	pit_cornering_utilisation = profile.get("pit_cornering_utilisation",profile.cornering_utilisation) * lerpf(profile.get("pit_minimum_cornering_factor",profile.get("minimum_cornering_factor",.8)),1.0,ratings.cornering/100.0)
	pit_braking_utilisation = profile.get("pit_braking_utilisation",profile.braking_utilisation) * lerpf(.65,1.0,ratings.braking/100.0)
	braking_margin_m = profile.braking_margin_m
	throttle_response = lerpf(.6,1.0,ratings.throttle/100.0)
	cornering_utilisation = cornering_base
	braking_utilisation = braking_base

func _exit_tree() -> void:
	if diagnostic != null:
		_flush_diagnostic()
		diagnostic.close()

func configure(vehicle: Node3D, race_data: Dictionary, delay: float, record_telemetry: bool = false) -> void:
	car = vehicle
	if record_telemetry and DirAccess.make_dir_recursive_absolute("user://telemetry") == OK:
		var path := "user://telemetry/ai_" + str(car.name) + "_" + Time.get_datetime_string_from_system().replace(":", "-") + ".csv"
		diagnostic = FileAccess.open(path, FileAccess.WRITE)
		if diagnostic != null:
			# Stagger each car's first batch so the field does not flush together.
			log_flush_elapsed = posmod(hash(str(car.name)),1000)/1000.0
			diagnostic.store_csv_line(DIAGNOSTIC_HEADER.split(","))
	if record_telemetry and diagnostic == null:
		push_warning("Could not open AI telemetry for "+str(car.name))
	release_delay = delay
	for p in race_data.points:
		race.append(Vector3(p[0],p[1],p[2]))
	# Omit duplicate end point; wrap explicitly when racing.
	if race[0].distance_to(race[-1]) < .1:
		race.resize(race.size()-1)
	_cache_race_distances()
	if race_data.get("racing_corridor") is Dictionary:
		racecraft.configure(race_data.racing_corridor,race,race_data.get("racecraft_tuning",{}))
		if not racecraft.enabled:
			push_warning("Invalid or stale racing corridor; using single-line AI")
	_build_departure()

func start_formation(lane_m: float, speed_kph: float, row: int = 0) -> void:
	formation_lane_m = lane_m
	formation_speed_kph = speed_kph
	formation_row = maxi(0,row)
	mode = Mode.FORMATION
	release_delay = 0.0
	index = 0
	var position: Vector3 = car.track.to_local(car.global_position)
	for i in range(1,race.size()):
		if position.distance_squared_to(race[i]) < position.distance_squared_to(race[index]):
			index = i

func release_to_race() -> void:
	if mode == Mode.FORMATION:
		mode = Mode.RACING
		# Hold the corridor lane occupied in reality, rather than assuming the
		# formation offset is an exact fraction of the racing-corridor width.
		racecraft.lane = racecraft.current_lane_choice(self)
		racecraft.target_lane = 0.0
		racecraft.begin_green_launch(racecraft.lane,racecraft.coordinates(self,car).y if racecraft.enabled else NAN,formation_row,car.speed_mps)

func _build_departure() -> void:
	route.clear()
	merge_committed = false
	merge_blocker = ""
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
	# Choose a point ahead on the actual racing line, then match both tangents.
	var end := route[-1]
	var entry_tangent := (end-route[-2]).normalized()
	var intended := end+entry_tangent*120.0
	for i in range(race.size()):
		if intended.distance_squared_to(race[i]) < intended.distance_squared_to(race[route_join_index]):
			route_join_index = i
	var join := race[route_join_index]
	var exit_tangent := (race[(route_join_index+1)%race.size()]-race[(route_join_index-1+race.size())%race.size()]).normalized()
	var span := end.distance_to(join)
	var gate_index := route.size()-1
	for i in range(1,41):
		var t := i/40.0
		# Cubic Hermite joins position and direction at both ends.
		route.append((2*t*t*t-3*t*t+1)*end+(t*t*t-2*t*t+t)*entry_tangent*span+(-2*t*t*t+3*t*t)*join+(t*t*t-t*t)*exit_tangent*span)
	route_distances = PackedFloat64Array([0.0])
	for i in range(route.size()-1):
		route_distances.append(route_distances[-1]+route[i].distance_to(route[i+1]))
	# Hold on the apron, before steering/lookahead starts crossing onto the road.
	merge_gate_m = route_distances[gate_index]-30.0

func _physics_process(delta: float) -> void:
	if car == null:
		return
	elapsed += delta
	_update_car_collisions()
	if not ratings.is_empty():
		if laps != form_lap:
			form_lap = laps
			form_target = 1.0-form_rng.randf_range(0,.03)*(1.0-ratings.consistency/100.0)
		form = move_toward(form,form_target,delta*.002)
		cornering_utilisation = cornering_base*form
		braking_utilisation = braking_base*form
	if mode == Mode.WAITING:
		if (not practice_cycle or practice_session.status == practice_session.Status.RUNNING) and elapsed >= release_delay and _departure_clear():
			mode = Mode.PIT_EXIT
		else:
			car.drive_step(delta,0,1,0)
			return
	var position: Vector3 = car.track.to_local(car.global_position)
	_update_index(position)
	if _update_practice_cycle():
		return
	racecraft.update(self,delta)
	var lookahead := clampf(5.0 + absf(car.speed_mps)*.48, 6, 30)
	var target: Vector3 = _formation_ahead(lookahead) if mode == Mode.FORMATION else racecraft.ahead(self,lookahead)
	var world_target: Vector3 = car.track.to_global(target)
	var offset: Vector3 = car.global_basis.inverse() * (world_target-car.global_position)
	offset.y = 0
	var curvature := -2.0*offset.x / maxf(offset.length_squared(),1)
	var p: Dictionary = car.parameters.values
	var speed: float = absf(car.speed_mps)
	var normal_g: float = 9.81 * (car.get_floor_normal().y if car.is_on_floor() else 1.0)
	var capacity: float = p.friction_coefficient*(normal_g+.5*p.air_density_kg_m3*p.downforce_area_m2*speed*speed/p.mass_kg)*p.corner_grip_fraction
	var lock: float = lerpf(p.steering_lock_deg,p.high_speed_lock_deg,clampf(speed/p.steering_reduction_speed_mps,0,1))
	var safe_lock: float = rad_to_deg(atan(p.wheelbase_m*capacity/maxf(speed*speed,1)))*p.steering_range_multiplier
	lock = lerpf(lock,minf(lock,safe_lock),p.assistance_strength)
	var steering := clampf(atan(curvature*p.wheelbase_m)*1.15/deg_to_rad(lock),-1,1)
	if mode == Mode.FORMATION:
		desired_speed_kph = formation_speed_kph
	elif mode == Mode.PIT_ENTRY:
		desired_speed_kph = _pit_entry_speed()*3.6
	elif mode == Mode.PIT_EXIT:
		desired_speed_kph = _pit_exit_speed()*3.6
	else:
		desired_speed_kph = _planned_speed()*3.6
		max_line_error_m = maxf(max_line_error_m, position.distance_to(_nearest_point(position)))
	car.update_zone_state()
	if car.player_state.is_in_pit_speed_zone:
		desired_speed_kph = minf(desired_speed_kph,car.track_data.speed_limit_kph)
	var target_mps := _traffic_speed(desired_speed_kph/3.6)
	if mode == Mode.PIT_EXIT and traffic_reason == "clear" and not merge_blocker.is_empty():
		traffic_reason = "merge_yield_"+merge_blocker
	var error: float = target_mps-car.speed_mps
	# Allow a small racing speed tolerance instead of alternating throttle and
	# brake for tiny sampled-target changes. Pit and traffic control stay strict.
	var racing_clear: bool = mode == Mode.RACING and traffic_reason == "clear" and not car.player_state.is_in_pit_speed_zone
	var tolerance := 0.5 if racing_clear else 0.0
	var throttle := clampf(error*.35 + (0.5 if racing_clear else .35),0,1)
	if racing_clear:
		throttle = clampf(error*.35*throttle_response + .5,0,1)
	var brake := clampf((-error-tolerance)*.18,0,1)
	if not is_finite(target_mps):
		throttle = 1.0
		brake = 0.0
	elif brake > 0:
		throttle = 0.0
	if target_mps < .1 and car.speed_mps < .5:
		throttle = 0
		brake = 1
	car.drive_step(delta,throttle,brake,steering)
	if diagnostic != null:
		log_elapsed += delta
		log_flush_elapsed += delta
	if diagnostic != null and log_elapsed >= .1:
		log_elapsed = 0
		var row := PackedStringArray()
		for value in [elapsed,mode,index,position.x,position.z,car.speed_mps*3.6,desired_speed_kph,target_mps*3.6,traffic_reason,throttle,brake,steering,car.sim.gear,car.sim.rpm(),int(car.is_on_floor()),car.get_slide_collision_count(),position.distance_to(_nearest_point(position)) if mode == Mode.RACING else 0]:
			row.append(str(value))
		for value in [racecraft.state,racecraft.lane,racecraft.target_lane,str(racecraft.opponent.name) if is_instance_valid(racecraft.opponent) else "",racecraft.passes]:
			row.append(str(value))
		# Numeric fields and identifier-only traffic reasons contain no CSV delimiters.
		pending_log_rows.append(",".join(row))
	if diagnostic != null and log_flush_elapsed >= 1.0:
		_flush_diagnostic()
		log_flush_elapsed = 0.0

func _flush_diagnostic() -> void:
	if diagnostic == null or pending_log_rows.is_empty():
		return
	diagnostic.store_string("\n".join(pending_log_rows)+"\n")
	pending_log_rows.clear()
	diagnostic.flush()

func _pit_exit_speed() -> float:
	merge_blocker = ""
	var request := _planned_speed()
	if index < 21:
		request = minf(request,55.0/3.6)
	if merge_committed:
		return request
	var position: Vector3 = car.track.to_local(car.global_position)
	var direction := (route[mini(index+1,route.size()-1)]-route[index]).normalized()
	var remaining := merge_gate_m-route_distances[index]-(position-route[index]).dot(direction)
	var p: Dictionary = car.parameters.values
	var decel: float = maxf(.1,minf(p.brake_force_n/p.mass_kg,p.friction_coefficient*9.81)*pit_braking_utilisation)
	if remaining <= car.speed_mps*car.speed_mps/(2*decel)+25.0:
		if _merge_clear():
			if remaining <= 25.0:
				merge_committed = true
		else:
			request = minf(request,sqrt(2*decel*maxf(0,remaining-5.0)))
	return request

func _planned_speed() -> float:
	var p: Dictionary = car.parameters.values
	var result := INF
	var decel: float = maxf(0.1, minf(p.brake_force_n/p.mass_kg,p.friction_coefficient*9.81)*(pit_braking_utilisation if mode == Mode.PIT_EXIT else braking_utilisation))
	# Include acceleration/control response before the next planning update.
	var speed: float = absf(car.speed_mps)
	var position: Vector3 = car.track.to_local(car.global_position)
	var points := race if mode == Mode.RACING else route
	var direction := (points[(index+1)%points.size()]-points[index]).normalized()
	var origin_offset := (position-points[index]).dot(direction)
	var horizon := minf(race_length_m, maxf(200.0, speed*speed/(2*decel)+speed*2.0+braking_margin_m))
	var intervals := int(ceil(horizon/10.0))
	# The centred stencils overlap: sample each shared point only once per tick.
	var samples: PackedVector3Array = racecraft.planner_samples(self,intervals*2+11)
	# Backward braking envelope over the upcoming route, using conservative grip.
	for step in range(intervals+1):
		var distance := step*10
		# Curvature belongs at the middle sample, measured from the car rather
		# than the nearest vertex. Include the current bend even on corner exit.
		# Estimate the sustained bend over the steering controller's spatial
		# response, rather than react to short entry/exit curvature peaks.
		var a := samples[step*2]
		var b := samples[step*2+5]
		var c := samples[step*2+10]
		var target := _corner_speed(a,b,c)
		result = minf(result,sqrt(target*target+2*decel*maxf(0,distance-origin_offset-braking_margin_m)))
	return result

func _corner_speed(a: Vector3, b: Vector3, c: Vector3) -> float:
	var p: Dictionary = car.parameters.values
	var incoming := (b-a).normalized()
	var outgoing := (c-b).normalized()
	var curvature := (outgoing-incoming)/maxf((a.distance_to(b)+b.distance_to(c))*.5,.001)
	# Static road normals are cached; exclude vehicles from the road query.
	var normal := Vector3.UP
	# Moving passing paths must not grow the normal cache every physics tick.
	var normal_key := b.snapped(Vector3(2,2,2)) if racecraft.enabled else b
	if car.is_inside_tree():
		if not surface_normals.has(normal_key):
			var world: Vector3 = car.track.to_global(b)
			var query := PhysicsRayQueryParameters3D.create(world+Vector3.UP*5,world-Vector3.UP*10,1)
			var excluded: Array[RID] = [car.get_rid()]
			for rival in rivals:
				excluded.append(rival.get_rid())
			query.exclude = excluded
			var hit: Dictionary = car.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				if surface_normals.size() >= 16384:
					surface_normals.clear()
				surface_normals[normal_key] = car.track.global_basis.inverse()*hit.normal
		if surface_normals.has(normal_key):
			normal = surface_normals[normal_key]
	var lateral := curvature.slide(normal)
	var bend := lateral.length()
	if bend < 0.00001:
		return INF
	# Reserve grip for line corrections and combined braking/cornering loads.
	var utilisation := pit_cornering_utilisation if mode == Mode.PIT_EXIT else cornering_utilisation
	# Passing grooves have tighter curvature and less room for corrections.
	# Reserve capacity before a lane change, including the return to the groove.
	if mode == Mode.RACING and racecraft.enabled and maxf(absf(racecraft.lane),absf(racecraft.target_lane)) > .01:
		utilisation = minf(utilisation,.92)
	var grip: float = p.friction_coefficient*p.corner_grip_fraction*utilisation
	var aero: float = .5*p.air_density_kg_m3*p.downforce_area_m2/p.mass_kg
	var gravity: Vector3 = car.track.global_basis.inverse()*(Vector3.DOWN*9.81)
	var available := maxf(0.0,grip*maxf(0,-gravity.dot(normal))+gravity.dot(lateral/bend))
	var denominator := bend-grip*aero
	# This simplified model has no lateral limit when aero outgrows demand.
	return sqrt(available/denominator) if denominator > 0 else INF

func _update_index(position: Vector3) -> void:
	var on_track := mode == Mode.RACING or mode == Mode.FORMATION
	var points := race if on_track else route
	var old := index
	var best := INF
	for step in range(-2,35):
		var candidate := posmod(index+step,points.size()) if on_track else clampi(index+step,0,points.size()-1)
		var distance := position.distance_squared_to(points[candidate])
		if distance < best:
			best = distance
			old = candidate
	if mode == Mode.RACING and index > race.size()-35 and old < 35:
		laps += 1
	index = old
	if mode == Mode.PIT_EXIT and index >= route.size()-3:
		mode = Mode.RACING
		stint_start_laps = _timed_laps()
		_update_car_collisions()
		index = 0
		for i in range(race.size()):
			if position.distance_squared_to(race[i]) < position.distance_squared_to(race[index]):
				index = i

func _ahead(distance: float) -> Vector3:
	if mode != Mode.RACING and mode != Mode.FORMATION and not route_distances.is_empty():
		var at := maxf(0.0,route_distances[index]+distance)
		if mode == Mode.PIT_ENTRY:
			return _sample_path(route,route_distances,minf(at,route_distances[-1]))
		if at <= route_distances[-1]:
			return _sample_path(route,route_distances,at)
		return _sample_path(race,race_distances,fposmod(race_distances[route_join_index]+at-route_distances[-1],race_length_m))
	if mode == Mode.RACING or mode == Mode.FORMATION:
		if race_distances.size() != race.size()+1:
			_cache_race_distances()
		if race_length_m <= .001:
			return race[index]
		var at := fposmod(race_distances[index]+distance,race_length_m)
		return _sample_path(race,race_distances,at)
	var on_track := mode == Mode.RACING or mode == Mode.FORMATION
	var points := race if on_track else route
	var current := index
	for unused in range(points.size()+1):
		var next := (current+1)%points.size() if on_track else mini(current+1,points.size()-1)
		var length := points[current].distance_to(points[next])
		if length >= distance or next == current:
			return points[current].lerp(points[next],clampf(distance/maxf(length,.001),0,1))
		distance -= length
		current = next
	return points[current]

func _formation_ahead(distance: float) -> Vector3:
	if racecraft.enabled:
		return racecraft.track_lane_point(self,distance,formation_lane_m)
	var center := _ahead(distance)
	var before := _ahead(maxf(0.0,distance-2.0))
	var after := _ahead(distance+2.0)
	var tangent := (after-before).normalized()
	return center+tangent.cross(Vector3.UP)*formation_lane_m

func _sample_path(points: PackedVector3Array, distances: PackedFloat64Array, at: float) -> Vector3:
	var low := 0
	var high := distances.size()-1
	while low+1 < high:
		var middle := (low+high)/2
		if distances[middle] <= at:
			low = middle
		else:
			high = middle
	var length := distances[low+1]-distances[low]
	return points[low].lerp(points[(low+1)%points.size()],clampf((at-distances[low])/maxf(length,.001),0,1))

func _cache_race_distances() -> void:
	race_distances = PackedFloat64Array([0.0])
	for i in range(race.size()):
		race_distances.append(race_distances[-1]+race[i].distance_to(race[(i+1)%race.size()]))
	race_length_m = race_distances[-1]

func _curvature_ahead() -> float:
	var a := _ahead(5)
	var b := _ahead(25)
	var c := _ahead(50)
	return (b-a).normalized().cross((c-b).normalized()).length()/25.0

func _nearest_point(position: Vector3) -> Vector3:
	return Geometry3D.get_closest_point_to_segment(position,race[index],race[(index+1)%race.size()])

func _traffic_speed(request: float) -> float:
	traffic_reason = "clear"
	if car_ghost:
		return request
	if mode == Mode.RACING and racecraft.enabled:
		return racecraft.traffic_speed(self,request)
	for other in rivals:
		if other == car or other.get_meta("pit_ghost",false):
			continue
		var relative: Vector3 = car.global_basis.inverse() * (other.global_position-car.global_position)
		var gap := -relative.z
		if gap > 0 and gap < maxf(12,car.speed_mps*2.0) and absf(relative.x) < 2.8 and car.global_basis.z.dot(other.global_basis.z) > .5:
			var following := maxf(0,other.speed_mps+(gap-8-maxf(0,car.speed_mps)*.65)*.6)
			if following < request:
				request = following
				traffic_reason = "following_" + str(other.name)
	return request

func _departure_clear() -> bool:
	for other in rivals:
		if other == car or other.get_meta("pit_ghost",false):
			continue
		var relative: Vector3 = car.global_basis.inverse() * (other.global_position-car.global_position)
		if relative.z < 6 and relative.z > -35 and relative.x > 1.5 and relative.x < 12:
			return false
	return true

func _merge_clear() -> bool:
	merge_blocker = ""
	var position: Vector3 = car.track.to_local(car.global_position)
	for other in rivals:
		if other == car:
			continue
		# Cars queued on this same pit-exit route are handled by following.
		# Counting them as approaching race traffic can make neighbours wait
		# for each other indefinitely when a larger field bunches at the merge.
		var other_driver = other.get_node_or_null("Driver")
		if other_driver != null and other_driver.mode != Mode.RACING:
			continue
		var p: Vector3 = car.track.to_local(other.global_position)
		if absf(p.z+125) >= 9:
			continue
		# Check separation when our paths overlap, not mere proximity now.
		# A same-speed car 50 m behind does not require a stop on the apron.
		var first_overlap := -1.0
		var start_distance := route_distances[index]
		for i in range(index,route.size()):
			if absf(route[i].z-p.z) < 3.5:
				first_overlap = maxf(0.0,route_distances[i]-start_distance)
				break
		if first_overlap < 0:
			continue
		var travel_speed := maxf(20.0,car.speed_mps)
		var enter_time := first_overlap/travel_speed
		var end_time := maxf(enter_time,(route_distances[-1]-start_distance)/travel_speed)
		# On this backstraight forward is -X. Positive gap means a car ahead.
		var gap := position.x-p.x
		var relative_speed: float = other.speed_mps-travel_speed
		var enter_gap := gap+relative_speed*enter_time
		var end_gap := gap+relative_speed*end_time
		var rear_space: float = 8.0+maxf(0,other.speed_mps-car.speed_mps)*.5
		if minf(enter_gap,end_gap) <= 8.0 and maxf(enter_gap,end_gap) >= -rear_space:
			merge_blocker = str(other.name)
			return false
	return true

func configure_practice(session_node: Node, seed_value: int) -> void:
	practice_cycle = true
	practice_session = session_node
	pit_box_pose = car.global_transform
	cycle_rng.seed = seed_value
	stint_laps = cycle_rng.randi_range(6,20)
	# Spread the first departures across two minutes.
	release_delay = cycle_rng.randf_range(4.0,120.0)
	var entry: Vector3 = car.track_data.pit_path[0]
	var nearest := 0
	for i in range(race.size()):
		if race[i].distance_squared_to(entry) < race[nearest].distance_squared_to(entry):
			nearest = i
	pit_approach_join_index = nearest
	while fposmod(race_distances[nearest]-race_distances[pit_approach_join_index],race_length_m) < 70.0:
		pit_approach_join_index = posmod(pit_approach_join_index-1,race.size())
	var approach := fposmod(race_distances[nearest]-300.0,race_length_m)
	for i in range(race.size()):
		if absf(race_distances[i]-approach) < absf(race_distances[pit_entry_index]-approach):
			pit_entry_index = i

func _timed_laps() -> int:
	var timing = car.get_parent().get("lap_timing")
	if timing != null:
		for entry in timing.entries:
			if entry.car == car:
				return entry.laps
	return laps

func _update_car_collisions() -> void:
	car_ghost = mode == Mode.WAITING or mode == Mode.PIT_ENTRY or mode == Mode.PIT_EXIT or car.player_state.is_in_pit_lane
	car.set_meta("pit_ghost",car_ghost)
	for other in rivals:
		if other == car:
			continue
		if car_ghost or other.get_meta("pit_ghost",false):
			car.add_collision_exception_with(other)
			other.add_collision_exception_with(car)
		else:
			car.remove_collision_exception_with(other)
			other.remove_collision_exception_with(car)

func _update_practice_cycle() -> bool:
	if not practice_cycle:
		return false
	if mode == Mode.RACING and (_timed_laps()-stint_start_laps >= stint_laps or practice_session.status == practice_session.Status.FINISHED):
		if posmod(index-pit_entry_index,race.size()) < 8:
			_begin_pit_entry()
	if mode == Mode.PIT_ENTRY:
		var position: Vector3 = car.track.to_local(car.global_position)
		if Vector2(position.x-route[-1].x,position.z-route[-1].z).length() < .8 and car.speed_mps < 1.0:
			car.global_transform = pit_box_pose
			car.reset_dynamics()
			car.player_state.speed_mps = 0.0
			mode = Mode.WAITING
			completed_stints += 1
			release_delay = elapsed+cycle_rng.randf_range(240.0,600.0)
			stint_laps = cycle_rng.randi_range(6,20)
			_build_departure()
			index = 0
			return true
	return false

func _begin_pit_entry() -> void:
	mode = Mode.PIT_ENTRY
	_update_car_collisions()
	var timing = car.get_parent().get("lap_timing")
	if timing != null:
		timing.invalidate(car)
	route.clear()
	var start: Vector3 = car.track.to_local(car.global_position)
	var pit: PackedVector3Array = car.track_data.pit_path
	# Follow Turn 3/4 before peeling off; a direct chord would cross the infield.
	route.append(start)
	var cursor := (index+1)%race.size()
	var lateral_offset := start-race[index]
	var travelled := 0.0
	while cursor != (pit_approach_join_index+1)%race.size():
		travelled += race[cursor].distance_to(race[posmod(cursor-1,race.size())])
		route.append(race[cursor]+lateral_offset*maxf(0.0,1.0-travelled/80.0))
		cursor = (cursor+1)%race.size()
	start = route[-1]
	var tangent := (race[(pit_approach_join_index+1)%race.size()]-race[pit_approach_join_index]).normalized()
	var end_tangent := (pit[1]-pit[0]).normalized()
	var span := start.distance_to(pit[0])
	for i in range(1,101):
		var t := i/100.0
		route.append((2*t*t*t-3*t*t+1)*start+(t*t*t-2*t*t+t)*tangent*span+(-2*t*t*t+3*t*t)*pit[0]+(t*t*t-t*t)*end_tangent*span)
	pit_entry_lane_distance = 0.0
	for i in range(route.size()-1):
		pit_entry_lane_distance += route[i].distance_to(route[i+1])
	var box: Vector3 = car.track.to_local(pit_box_pose.origin)
	for point in pit:
		if point.x >= box.x-35.0:
			break
		if point.distance_to(route[-1]) > .1:
			route.append(point)
	var turn := route[-1]
	for i in range(1,31):
		var t := i/30.0
		route.append(Vector3(lerpf(turn.x,box.x,t),lerpf(turn.y,box.y,t),lerpf(turn.z,box.z,t*t*(3.0-2.0*t))))
	route_distances = PackedFloat64Array([0.0])
	for i in range(route.size()-1):
		route_distances.append(route_distances[-1]+route[i].distance_to(route[i+1]))
	index = 0

func _pit_entry_speed() -> float:
	var position: Vector3 = car.track.to_local(car.global_position)
	var next := mini(index+1,route.size()-1)
	var offset := maxf(0.0,(position-route[index]).dot((route[next]-route[index]).normalized()))
	var progress := route_distances[index]+offset
	var remaining := maxf(0.0,route_distances[-1]-progress)
	var lane_speed: float = car.track_data.speed_limit_kph/3.6
	# Brake before the lane and progressively slow for the stall approach.
	var speed := sqrt(lane_speed*lane_speed+2.0*8.0*maxf(0.0,pit_entry_lane_distance-progress-10.0))
	speed = minf(speed,sqrt(2.0*3.0*remaining))
	return minf(speed,8.0) if remaining < 40.0 else speed
