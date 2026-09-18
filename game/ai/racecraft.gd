extends RefCounted
## Two-wide planning in track coordinates. Does not modify vehicle physics.
var inner := PackedVector3Array()
var outer := PackedVector3Array()
var inside := PackedVector3Array()
var outside := PackedVector3Array()
var lane := 0.0
var target_lane := 0.0
var state := "clear"
var opponent: Node3D
var committed_s := 0.0
var best_opponent_gap := INF
var no_progress_s := 0.0
var cooldown_s := 0.0
var passes := 0
var attempts := 0
var aborted := 0
var nearby: Array[Dictionary] = []
var own := Vector2.ZERO
var enabled := false
var lane_change_blocked := false
const TUNING_PATH := "res://content/racecraft.json"
const TUNING_DEFAULTS := {
	"passing_speed_factor": 1.02,
	"road_edge_speed_start_m": 7.0,
	"alongside_gap_m": 4.5,
	"room_status_rear_gap_m": 10.0,
	"nearby_room_gap_m": 20.0,
	"room_status_lateral_m": 1.5,
	"closing_speed_mps": 0.8,
	"passing_status_gap_m": 10.0,
	"passing_commit_min_gap_m": 25.0,
	"passing_commit_max_gap_m": 40.0,
	"passing_abandon_gap_m": 110.0,
	"passing_no_progress_s": 50.0,
	"lane_blend_distance_m": 30.0,
	"collision_guard_gap_m": 9.0,
	"collision_guard_gain": 1.4,
	"green_launch_guard_delay_s": 1.5,
	"green_launch_lane_hold_s": 1.5,
	"green_launch_acceleration_mps2": 5.0,
	"green_launch_acceleration_window_s": 5.0,
	"green_launch_row_delay_s": 0.1,
}
## Shared defaults are loaded from content/racecraft.json. A track can supply
## individual overrides through its ai/racecraft.json file.
var passing_speed_factor := 1.02
var road_edge_speed_start_m := 7.0
var alongside_gap_m := 4.5
var room_status_rear_gap_m := 10.0
var nearby_room_gap_m := 20.0
var room_status_lateral_m := 1.5
var closing_speed_mps := 0.8
var passing_status_gap_m := 10.0
var passing_commit_min_gap_m := 25.0
var passing_commit_max_gap_m := 40.0
var passing_abandon_gap_m := 110.0
var passing_no_progress_s := 50.0
var lane_blend_distance_m := 30.0
var collision_guard_gap_m := 9.0
var collision_guard_gain := 1.4
var green_launch_guard_delay_s := 1.5
var green_launch_guard_remaining_s := 0.0
var green_launch_lane_hold_s := 1.5
var green_launch_lane_hold_remaining_s := 0.0
var green_launch_lane := 0.0
var launch_lateral_m := 0.0
var launch_weight := 0.0
var green_launch_acceleration_mps2 := 5.0
var green_launch_acceleration_window_s := 5.0
var green_launch_row_delay_s := 0.1
var green_launch_row_delay_remaining_s := 0.0
var green_launch_acceleration_remaining_s := 0.0
var green_launch_speed_cap_mps := INF
const PROJECTION_BLOCK_SIZE := 16
var projection_points := PackedVector2Array()
var projection_blocks: Array[Rect2] = []
var projection_cache: Dictionary = {}

func configure(data: Dictionary, race: PackedVector3Array, overrides: Dictionary = {}) -> void:
	enabled = false
	projection_points.clear()
	projection_blocks.clear()
	projection_cache.clear()
	_load_tuning(overrides)
	if data.get("schema_version") != 1 or data.get("units") != "metres":
		return
	var speed_factor = passing_speed_factor
	if not (speed_factor is float or speed_factor is int) or not is_finite(speed_factor) or speed_factor <= 0 or speed_factor > 1.08:
		return
	passing_speed_factor = speed_factor
	for key in ["reference_points", "inner", "outer", "inside", "outside"]:
		if not data.get(key) is Array or data[key].size() != race.size()+1:
			return
		for p in data[key]:
			if not p is Array or p.size() != 3:
				return
			for value in p:
				if not (value is float or value is int) or not is_finite(value):
					return
		if Vector3(data[key][0][0],data[key][0][1],data[key][0][2]).distance_to(Vector3(data[key][-1][0],data[key][-1][1],data[key][-1][2])) > .01:
			return
	for i in range(race.size()):
		var p: Array = data.reference_points[i]
		if race[i].distance_to(Vector3(p[0],p[1],p[2])) > .01:
			return
	inner = _points(data.inner, race.size())
	outer = _points(data.outer, race.size())
	inside = _points(data.inside, race.size())
	outside = _points(data.outside, race.size())
	for i in range(race.size()):
		var width := inner[i].distance_to(outer[i])
		if width < 10 or inside[i].distance_to(outside[i]) < 5:
			return
		for point in [inside[i],outside[i],race[i]]:
			if point.distance_to(Geometry3D.get_closest_point_to_segment(point,inner[i],outer[i])) > .05:
				return
		projection_points.append(Vector2(race[i].x,race[i].z))
	for first in range(0,race.size(),PROJECTION_BLOCK_SIZE):
		var bounds := Rect2(projection_points[first],Vector2.ZERO)
		for i in range(first,mini(first+PROJECTION_BLOCK_SIZE,race.size())):
			bounds = bounds.expand(projection_points[(i+1)%race.size()])
		projection_blocks.append(bounds)
	enabled = true

func _load_tuning(overrides: Dictionary) -> void:
	var values: Dictionary = TUNING_DEFAULTS.duplicate()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(TUNING_PATH))
	if parsed is Dictionary and parsed.get("schema_version") == 1 and parsed.get("units") == "metres_seconds" and parsed.get("tuning") is Dictionary:
		_merge_tuning(values,parsed.tuning,TUNING_PATH)
	else:
		push_warning("Invalid racecraft defaults; using built-in values")
	_merge_tuning(values,overrides,"track racecraft overrides")
	passing_speed_factor = values.passing_speed_factor
	road_edge_speed_start_m = values.road_edge_speed_start_m
	alongside_gap_m = values.alongside_gap_m
	room_status_rear_gap_m = values.room_status_rear_gap_m
	nearby_room_gap_m = values.nearby_room_gap_m
	room_status_lateral_m = values.room_status_lateral_m
	closing_speed_mps = values.closing_speed_mps
	passing_status_gap_m = values.passing_status_gap_m
	passing_commit_min_gap_m = values.passing_commit_min_gap_m
	passing_commit_max_gap_m = values.passing_commit_max_gap_m
	passing_abandon_gap_m = values.passing_abandon_gap_m
	passing_no_progress_s = values.passing_no_progress_s
	lane_blend_distance_m = values.lane_blend_distance_m
	collision_guard_gap_m = values.collision_guard_gap_m
	collision_guard_gain = values.collision_guard_gain
	green_launch_guard_delay_s = values.green_launch_guard_delay_s
	green_launch_lane_hold_s = values.green_launch_lane_hold_s
	green_launch_acceleration_mps2 = values.green_launch_acceleration_mps2
	green_launch_acceleration_window_s = values.green_launch_acceleration_window_s
	green_launch_row_delay_s = values.green_launch_row_delay_s
	if passing_commit_min_gap_m <= 20.0 or passing_commit_max_gap_m <= passing_commit_min_gap_m:
		push_warning("Racecraft pass-entry range must stay above the 20 m lane-crossing reserve; using defaults")
		passing_commit_min_gap_m = TUNING_DEFAULTS.passing_commit_min_gap_m
		passing_commit_max_gap_m = TUNING_DEFAULTS.passing_commit_max_gap_m

func _merge_tuning(values: Dictionary, incoming: Dictionary, source: String) -> void:
	for key in incoming:
		if not TUNING_DEFAULTS.has(key):
			push_warning("Unknown racecraft tuning key %s in %s" % [key,source])
			continue
		var value = incoming[key]
		if not (value is float or value is int) or not is_finite(value) or value <= 0 or (key == "passing_speed_factor" and value > 1.08):
			push_warning("Invalid racecraft tuning value for %s in %s" % [key,source])
			continue
		values[key] = float(value)

func begin_green_launch(formation_lane: float, lateral_m: float = NAN, grid_row: int = 0, initial_speed_mps: float = 0.0) -> void:
	# Formation gaps are deliberately tight. Let the whole field take throttle
	# together in its existing row before converging on RACE. This avoids a
	# side-by-side pair steering into the same groove at the green flag.
	green_launch_guard_remaining_s = green_launch_guard_delay_s
	green_launch_lane_hold_remaining_s = green_launch_lane_hold_s
	green_launch_lane = clampf(formation_lane,-1.0,1.0)
	target_lane = green_launch_lane
	lane = green_launch_lane
	launch_weight = 1.0 if is_finite(lateral_m) else 0.0
	launch_lateral_m = lateral_m if is_finite(lateral_m) else 0.0
	# Keep each two-car row together, with a small cumulative release delay for
	# rows behind it. This creates natural field spread without slowing lap pace.
	green_launch_row_delay_remaining_s = maxf(0.0,float(grid_row)*green_launch_row_delay_s)
	green_launch_acceleration_remaining_s = green_launch_acceleration_window_s
	green_launch_speed_cap_mps = maxf(0.0,initial_speed_mps)

func current_lane_choice(driver) -> float:
	# Express position as a RACE-to-PASS blend for tactical bookkeeping. RACE
	# is not track centre, so subtract its lateral coordinate before dividing.
	# Launch steering itself uses the physical track-relative lane below.
	if not enabled:
		return 0.0
	var lateral := coordinates(driver,driver.car).y
	var base_lateral := lane_lateral(driver,0.0,0.0)
	var inside_lateral := lane_lateral(driver,-1.0,0.0)
	var outside_lateral := lane_lateral(driver,1.0,0.0)
	if lateral < base_lateral and inside_lateral < base_lateral-.001:
		return -clampf((base_lateral-lateral)/(base_lateral-inside_lateral),0.0,1.0)
	if lateral > base_lateral and outside_lateral > base_lateral+.001:
		return clampf((lateral-base_lateral)/(outside_lateral-base_lateral),0.0,1.0)
	return 0.0

func track_lane_point(driver, distance: float, lateral_m: float) -> Vector3:
	var at: float = fposmod(driver.race_distances[driver.index]+distance,driver.race_length_m)
	var low: Vector3 = driver._sample_path(inner,driver.race_distances,at)
	var high: Vector3 = driver._sample_path(outer,driver.race_distances,at)
	return low.lerp(high,clampf((lateral_m+8.0)/16.0,0.0,1.0))

func speed_factor() -> float:
	# Apply the tow only to the attacking car. A leader moving aside to leave
	# room also uses an alternate groove but must not receive the same benefit.
	var commitment := maxf(absf(lane),absf(target_lane)) if opponent != null else 0.0
	return lerpf(1.0,passing_speed_factor,commitment)

func _points(values: Array, count: int) -> PackedVector3Array:
	var result := PackedVector3Array()
	for i in range(count):
		result.append(Vector3(values[i][0],values[i][1],values[i][2]))
	return result

func coordinates(driver, vehicle: Node3D) -> Vector2:
	var p: Vector3 = driver.car.track.to_local(vehicle.global_position)
	var other_driver = vehicle.get_node_or_null("Driver")
	var hint: int = other_driver.index if other_driver != null and other_driver.mode == 2 else -1
	var id := vehicle.get_instance_id()
	var cached: Dictionary = projection_cache.get(id,{})
	if not cached.is_empty() and cached.position == p and cached.hint == hint:
		return cached.result
	var point := Vector2(p.x,p.z)
	var best := INF
	var best_index := 0
	var best_t := 0.0
	var candidates := PackedInt32Array()
	if hint >= 0:
		for step in range(7):
			candidates.append(posmod(hint+step-3,projection_points.size()))
	else:
		# Seed an exact upper bound from the closest block, then exclude blocks
		# whose bounding rectangle cannot contain a better segment. No approximation.
		var nearest_block := 0
		var nearest_bound := INF
		for block in range(projection_blocks.size()):
			var distance := _block_distance_squared(point,projection_blocks[block])
			if distance < nearest_bound:
				nearest_bound = distance
				nearest_block = block
		var first := nearest_block*PROJECTION_BLOCK_SIZE
		var upper := INF
		for i in range(first,mini(first+PROJECTION_BLOCK_SIZE,projection_points.size())):
			upper = minf(upper,point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point,projection_points[i],projection_points[(i+1)%projection_points.size()])))
		# Preserve ascending segment order, including ties at vertices and lap seam.
		for block in range(projection_blocks.size()):
			if _block_distance_squared(point,projection_blocks[block]) <= upper+.001:
				first = block*PROJECTION_BLOCK_SIZE
				for i in range(first,mini(first+PROJECTION_BLOCK_SIZE,projection_points.size())):
					candidates.append(i)
	for i in candidates:
		var a := projection_points[i]
		var b := projection_points[(i+1)%projection_points.size()]
		var t := clampf((point-a).dot(b-a)/maxf(a.distance_squared_to(b),.001),0,1)
		var error := point.distance_squared_to(a.lerp(b,t))
		if error < best:
			best = error
			best_index = i
			best_t = t
	var next := (best_index+1)%projection_points.size()
	var low := inner[best_index].lerp(inner[next],best_t)
	var high := outer[best_index].lerp(outer[next],best_t)
	var outward := Vector2(high.x-low.x,high.z-low.z).normalized()
	var result := Vector2(lerpf(driver.race_distances[best_index],driver.race_distances[best_index+1],best_t),(point-Vector2(low.x,low.z)).dot(outward)-8.0)
	# At most one exact-position result per observed vehicle. Bound removed cars too.
	if projection_cache.size() >= 128:
		projection_cache.clear()
	projection_cache[id] = {"position":p,"hint":hint,"result":result}
	return result

func _block_distance_squared(point: Vector2, bounds: Rect2) -> float:
	var closest := point.clamp(bounds.position,bounds.end)
	return point.distance_squared_to(closest)

func gap(driver, s: float) -> float:
	return fposmod(s-own.x+driver.race_length_m*.5,driver.race_length_m)-driver.race_length_m*.5

func update(driver, delta: float) -> void:
	if not enabled or driver.mode != 2:
		return
	committed_s += delta
	cooldown_s = maxf(0,cooldown_s-delta)
	green_launch_guard_remaining_s = maxf(0,green_launch_guard_remaining_s-delta)
	green_launch_lane_hold_remaining_s = maxf(0,green_launch_lane_hold_remaining_s-delta)
	if green_launch_row_delay_remaining_s > 0.0:
		green_launch_row_delay_remaining_s = maxf(0.0,green_launch_row_delay_remaining_s-delta)
	elif green_launch_acceleration_remaining_s > 0.0:
		green_launch_acceleration_remaining_s = maxf(0.0,green_launch_acceleration_remaining_s-delta)
		green_launch_speed_cap_mps += green_launch_acceleration_mps2*delta
	own = coordinates(driver,driver.car)
	nearby.clear()
	for vehicle in driver.rivals:
		if vehicle == driver.car or not is_instance_valid(vehicle) or vehicle.get_meta("pit_ghost",false):
			continue
		if vehicle.global_position.distance_squared_to(driver.car.global_position) > 340*340:
			continue
		var p := coordinates(driver,vehicle)
		if absf(p.y) > 11:
			continue
		var separation := gap(driver,p.x)
		nearby.append({"car":vehicle,"gap":separation,"lateral":p.y})
	if launch_weight > 0.0:
		# A fixed track-relative lane does not sweep outward with RACE at corner
		# exit. Keep it until the timer AND the neighbouring row are clear.
		var beside := false
		for other in nearby:
			if absf(other.gap) < nearby_room_gap_m and absf(other.lateral-own.y) > room_status_lateral_m:
				beside = true
		if green_launch_lane_hold_remaining_s <= 0.0 and not beside and lane_clear(driver,0.0):
			launch_weight = move_toward(launch_weight,0.0,maxf(8.0,driver.car.speed_mps)*delta/lane_blend_distance_m)
		state = "alongside" if beside else "holding_lane"
		if launch_weight <= 0.0:
			lane = 0.0
			target_lane = 0.0
		return
	var overlapping := false
	for other in nearby:
		if absf(other.gap) < 18:
			overlapping = true
	if is_instance_valid(opponent):
		var separation := gap(driver,coordinates(driver,opponent).x)
		if best_opponent_gap == INF or separation < best_opponent_gap-.5:
			best_opponent_gap = separation
			no_progress_s = 0.0
		else:
			no_progress_s += delta
		if separation < -22 and committed_s > 2:
			passes += 1
			opponent = null
			best_opponent_gap = INF
			no_progress_s = 0.0
			cooldown_s = 2
		# Judge the attempt by sustained gap progress. Instantaneous speed is
		# misleading under corner braking and previously cancelled valid passes.
		elif not overlapping and ((committed_s > 2 and separation > passing_abandon_gap_m) or (no_progress_s > passing_no_progress_s and separation > 20)):
			aborted += 1
			opponent = null
			best_opponent_gap = INF
			no_progress_s = 0.0
			cooldown_s = 4
	else:
		opponent = null
		best_opponent_gap = INF
		no_progress_s = 0.0
	var desired := target_lane if opponent != null else (green_launch_lane if green_launch_lane_hold_remaining_s > 0 else 0.0)
	if opponent != null:
		var opponent_gap := gap(driver,coordinates(driver,opponent).x)
		state = "passing_inside" if opponent_gap < passing_status_gap_m and desired < 0 else ("passing_outside" if opponent_gap < passing_status_gap_m and desired > 0 else "closing")
	else:
		state = "clear"
	# Hold the established groove against a committed attacker.  The previous
	# response moved the leading car to the opposite passing groove while the
	# attacker was still behind, which looked like an eager defensive pull to
	# the inside and surrendered the preferred line.  A pass lane is already
	# clear of RACE, so neither car needs an extra defensive lane swap.
	for other in nearby:
		var rival_driver = other.car.get_node_or_null("Driver")
		var closing_speed: float = other.car.speed_mps-driver.car.speed_mps
		var predicted_gap: float = other.gap+closing_speed
		var approaching: bool = other.gap < 0 and other.gap > -room_status_rear_gap_m and closing_speed > closing_speed_mps and predicted_gap > -alongside_gap_m and rival_driver != null and rival_driver.racecraft.opponent == driver.car
		if absf(other.gap) < nearby_room_gap_m or approaching:
			var side: float = other.lateral-own.y
			if approaching:
				side = rival_driver.racecraft.target_lane
			if absf(side) > room_status_lateral_m or approaching:
				# A car in PASS1/PASS2 has 7.5 m of lateral separation from RACE.
				# Keep RACE (or the lane already held). This makes the leader
				# predictable and makes the attacker earn the pass instead of
				# receiving a pre-emptive inside-line concession.
				# The tactical window is retained for the HUD, but it no longer
				# commands a defensive lane change before overlap.
				if opponent == null:
					state = "alongside" if absf(other.gap) < alongside_gap_m else "leaving_room"
	# Begin a pass early enough to establish lateral clearance before catching.
	if opponent == null and state == "clear" and cooldown_s <= 0:
		var leader: Dictionary = {}
		for other in nearby:
			if other.gap > passing_commit_min_gap_m and other.gap < passing_commit_max_gap_m and absf(other.lateral-own.y) < 5:
				if leader.is_empty() or other.gap < leader.gap:
					leader = other
		if not leader.is_empty():
			# Use the requested pace before collision guarding. The guard is only
			# active at close range and must not conceal a pass opportunity.
			var closing_speed: float = maxf(driver.car.speed_mps,driver.desired_speed_kph/3.6)-leader.car.speed_mps
			if closing_speed > closing_speed_mps:
				var preferred := -1.0 if leader.lateral > 0 else 1.0
				for candidate in [preferred,-preferred]:
					if lane_clear(driver,candidate,leader.car):
						desired = candidate
						opponent = leader.car
						committed_s = 0
						best_opponent_gap = leader.gap
						no_progress_s = 0.0
						attempts += 1
						state = "passing_inside" if leader.gap < passing_status_gap_m and desired < 0 else ("passing_outside" if leader.gap < passing_status_gap_m and desired > 0 else "closing")
						break
	# Never cross through another car to return to the ideal line or change lanes.
	if desired != target_lane and not lane_clear(driver,desired,opponent):
		desired = target_lane
		state = "holding_lane"
	target_lane = desired
	# Use the configured full-blend distance; preview uses the same transition.
	# Recheck an in-progress move too: a player or another passer can occupy
	# its swept corridor after the initial commitment.
	lane_change_blocked = not is_equal_approx(lane,target_lane) and not lane_clear(driver,target_lane,opponent)
	if lane_change_blocked:
		state = "holding_lane"
	else:
		lane = move_toward(lane,target_lane,maxf(8,driver.car.speed_mps)*delta/lane_blend_distance_m)
	if opponent == null and state == "clear" and absf(lane) > .01:
		state = "returning"

func lane_clear(driver, candidate: float, ignored: Node3D = null) -> bool:
	var destination := lane_lateral(driver,candidate,0)
	for other in nearby:
		if other.car == ignored and absf(other.gap) > 20:
			continue
		# A rear car continuing on RACE must not pin this car to RACE. Moving
		# away from it increases lateral clearance; it only blocks the manoeuvre
		# if it is already established in, or committed to, the destination lane.
		if other.gap < 0 and absf(other.lateral-destination) > 3.2:
			var rear_driver = other.car.get_node_or_null("Driver")
			var rear_claims_destination := rear_driver != null and absf(rear_driver.racecraft.target_lane-candidate) < .25
			if not rear_claims_destination:
				continue
		var future: float = other.gap+(other.car.speed_mps-driver.car.speed_mps)*2.0
		if minf(other.gap,future) < 24 and maxf(other.gap,future) > -24:
			if other.lateral > minf(own.y,destination)-3.2 and other.lateral < maxf(own.y,destination)+3.2:
				return false
	return true

func lane_lateral(driver, choice: float, distance: float) -> float:
	var at: float = fposmod(driver.race_distances[driver.index]+distance,driver.race_length_m)
	var low: Vector3 = driver._sample_path(inner,driver.race_distances,at)
	var high: Vector3 = driver._sample_path(outer,driver.race_distances,at)
	var point := path_point(driver,distance,choice)
	var outward := Vector2(high.x-low.x,high.z-low.z).normalized()
	return Vector2(point.x-low.x,point.z-low.z).dot(outward)-8.0

func path_point(driver, distance: float, choice: float) -> Vector3:
	var base: Vector3 = driver._ahead(distance)
	if absf(choice) < .0001:
		return base
	var at: float = fposmod(driver.race_distances[driver.index]+distance,driver.race_length_m)
	var alternative: Vector3 = driver._sample_path(inside if choice < 0 else outside,driver.race_distances,at)
	return base.lerp(alternative,absf(choice))

func ahead(driver, distance: float) -> Vector3:
	if not enabled or driver.mode != 2:
		return driver._ahead(distance)
	if launch_weight > 0.0:
		return driver._ahead(distance).lerp(track_lane_point(driver,distance,launch_lateral_m),launch_weight)
	var preview := lane if lane_change_blocked else move_toward(lane,target_lane,maxf(0,distance)/lane_blend_distance_m)
	return _leave_side_room(driver,distance,path_point(driver,distance,preview))

func _leave_side_room(driver, distance: float, point: Vector3) -> Vector3:
	# RACE and a passing groove can converge as the ideal line crosses the
	# track. An established neighbour needs physical room even when neither
	# car is changing its lane selection. Preserve their current lateral order.
	var minimum := -8.0
	var maximum := 8.0
	var alongside := false
	for other in nearby:
		if absf(other.gap) >= 9.0:
			continue
		var side: float = own.y-other.lateral
		if absf(side) < 1.0:
			continue # Nose-to-tail traffic belongs to the longitudinal guard.
		alongside = true
		if side > 0:
			minimum = maxf(minimum,other.lateral+3.2)
		else:
			maximum = minf(maximum,other.lateral-3.2)
	if not alongside:
		return point
	var at: float = fposmod(driver.race_distances[driver.index]+distance,driver.race_length_m)
	var low: Vector3 = driver._sample_path(inner,driver.race_distances,at)
	var high: Vector3 = driver._sample_path(outer,driver.race_distances,at)
	var across := high-low
	var lateral := (point-low).dot(across)/maxf(across.length_squared(),.001)*16.0-8.0
	# If squeezed from both sides, hold the present physical lane.
	lateral = clampf(lateral,minimum,maximum) if minimum <= maximum else own.y
	return low.lerp(high,clampf((lateral+8.0)/16.0,0,1))

func planner_samples(driver, count: int) -> PackedVector3Array:
	var result := PackedVector3Array()
	result.resize(count)
	if launch_weight > 0.0 or not enabled or driver.mode != 2 or inside.size() != driver.race.size() or driver.race_length_m <= .001:
		for i in range(count):
			result[i] = ahead(driver,float(i*5-25))
		return result
	# Lookahead is ordered. Walk the line once instead of binary-searching both
	# the ideal and alternate paths independently for every curvature sample.
	var distances: PackedFloat64Array = driver.race_distances
	var points: PackedVector3Array = driver.race
	var origin: float = distances[driver.index]
	var previous: float = fposmod(origin-25,driver.race_length_m)
	var low := 0
	var high := distances.size()-1
	while low+1 < high:
		var middle := (low+high)/2
		if distances[middle] <= previous:
			low = middle
		else:
			high = middle
	for i in range(count):
		var distance := float(i*5-25)
		var at: float = fposmod(origin+distance,driver.race_length_m)
		if at < previous:
			low = 0
		while low+1 < points.size() and distances[low+1] <= at:
			low += 1
		var next := (low+1)%points.size()
		var fraction := clampf((at-distances[low])/maxf(distances[low+1]-distances[low],.001),0,1)
		var point := points[low].lerp(points[next],fraction)
		var choice := lane if lane_change_blocked else move_toward(lane,target_lane,maxf(0,distance)/lane_blend_distance_m)
		if absf(choice) >= .0001:
			var alternative := inside[low].lerp(inside[next],fraction) if choice < 0 else outside[low].lerp(outside[next],fraction)
			point = point.lerp(alternative,absf(choice))
		result[i] = _leave_side_room(driver,distance,point)
		previous = at
	return result

func traffic_speed(driver, request: float) -> float:
	# A legal target does not guarantee the body stays on it. Shed speed early
	# when tracking error consumes the road-edge reserve, retaining lane priority.
	if absf(own.y) > road_edge_speed_start_m:
		request = minf(request,maxf(15,driver.car.speed_mps)*clampf(1.0-(absf(own.y)-road_edge_speed_start_m)*.15,.65,1.0))
		driver.traffic_reason = "road_edge"
	if green_launch_row_delay_remaining_s > 0.0 or green_launch_acceleration_remaining_s > 0.0:
		request = minf(request,green_launch_speed_cap_mps)
	if green_launch_guard_remaining_s > 0:
		return request
	for other in nearby:
		if other.gap <= 0 or other.gap > maxf(15,driver.car.speed_mps*3.5):
			continue
		var intended := lane_lateral(driver,target_lane,other.gap)
		if launch_weight > 0.0:
			intended = lerpf(lane_lateral(driver,0.0,other.gap),launch_lateral_m,launch_weight)
		var separated: bool = absf(other.lateral-own.y) > 4.2 and absf(other.lateral-intended) > 4.2
		if separated:
			continue
		# Retain the short-gap response for close traffic, then constrain it
		# by stopping distance below when the speed difference needs more room.
		var guarded_speed: float = maxf(0,other.car.speed_mps+(other.gap-collision_guard_gap_m)*collision_guard_gain)
		# The short-gap proportional guard alone reacts too late to a stopped
		# car or a large speed difference. Reserve braking distance and 0.25 s
		# of closing travel while still allowing small pace differences to race.
		var closing := maxf(0,driver.car.speed_mps-other.car.speed_mps)
		var braking := 12.0
		var reference_braking = driver.car.get("braking_limit")
		if reference_braking != null:
			braking = float(reference_braking)*.8
		var room := maxf(0,other.gap-collision_guard_gap_m-closing*.25)
		var leader_speed := maxf(0,other.car.speed_mps)
		var safe_speed := sqrt(leader_speed*leader_speed+2.0*braking*room)
		guarded_speed = minf(guarded_speed,safe_speed)
		if guarded_speed < request:
			request = guarded_speed
			driver.traffic_reason = "collision_guard_"+str(other.car.name)
	return request
