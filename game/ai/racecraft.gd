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
var cooldown_s := 0.0
var passes := 0
var attempts := 0
var aborted := 0
var nearby: Array[Dictionary] = []
var own := Vector2.ZERO
var enabled := false
## PASS1/PASS2 initially share the clean-air race.lp speed profile.  A small
## authored reduction leaves margin for their longer/tighter alternate grooves.
var passing_speed_factor := .985
var road_edge_speed_start_m := 7.0
const PROJECTION_BLOCK_SIZE := 16
var projection_points := PackedVector2Array()
var projection_blocks: Array[Rect2] = []
var projection_cache: Dictionary = {}

func configure(data: Dictionary, race: PackedVector3Array) -> void:
	enabled = false
	projection_points.clear()
	projection_blocks.clear()
	projection_cache.clear()
	if data.get("schema_version") != 1 or data.get("units") != "metres":
		return
	var speed_factor = data.get("passing_speed_factor",.985)
	if not (speed_factor is float or speed_factor is int) or not is_finite(speed_factor) or speed_factor <= 0 or speed_factor > 1:
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

func speed_factor() -> float:
	# Apply the reserve while a lane change is requested, not only once the
	# car has reached the alternative path.
	return lerpf(1.0,passing_speed_factor,maxf(absf(lane),absf(target_lane)))

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
	own = coordinates(driver,driver.car)
	nearby.clear()
	for vehicle in driver.rivals:
		if vehicle == driver.car or not is_instance_valid(vehicle):
			continue
		if vehicle.global_position.distance_squared_to(driver.car.global_position) > 180*180:
			continue
		var p := coordinates(driver,vehicle)
		if absf(p.y) > 11:
			continue
		var separation := gap(driver,p.x)
		nearby.append({"car":vehicle,"gap":separation,"lateral":p.y})
	var overlapping := false
	for other in nearby:
		if absf(other.gap) < 18:
			overlapping = true
	if is_instance_valid(opponent):
		var separation := gap(driver,coordinates(driver,opponent).x)
		if separation < -22 and committed_s > 2:
			passes += 1
			opponent = null
			cooldown_s = 2
		elif committed_s > 12 and separation > 20 and not overlapping:
			aborted += 1
			opponent = null
			cooldown_s = 4
	else:
		opponent = null
	var desired := target_lane if opponent != null else 0.0
	state = "passing_inside" if desired < 0 else ("passing_outside" if desired > 0 else "clear")
	# Respect actual overlap and a near, genuinely closing rival's committed
	# passing lane.  Do not start defending a straight merely because an
	# attacker has selected a path many car lengths behind.
	for other in nearby:
		var rival_driver = other.car.get_node_or_null("Driver")
		var closing_speed: float = other.car.speed_mps-driver.car.speed_mps
		var predicted_gap: float = other.gap+closing_speed
		var approaching: bool = other.gap < 0 and other.gap > -30 and closing_speed > .8 and predicted_gap > -18 and rival_driver != null and rival_driver.racecraft.opponent == driver.car
		if absf(other.gap) < 20 or approaching:
			var side: float = other.lateral-own.y
			if approaching:
				side = rival_driver.racecraft.target_lane
			if absf(side) > 1.5 or approaching:
				desired = -1.0 if side > 0 else 1.0
				state = "alongside" if absf(other.gap) < 20 else "leaving_room"
	# Begin a pass early enough to establish lateral clearance before catching.
	if opponent == null and state == "clear" and cooldown_s <= 0:
		var leader: Dictionary = {}
		for other in nearby:
			if other.gap > 20 and other.gap < 110 and absf(other.lateral-own.y) < 5:
				if leader.is_empty() or other.gap < leader.gap:
					leader = other
		if not leader.is_empty():
			var rival_driver = leader.car.get_node_or_null("Driver")
			var faster: bool = driver.car.speed_mps > leader.car.speed_mps+.8
			if rival_driver != null:
				faster = faster or driver.cornering_base > rival_driver.cornering_base+.008
			if faster:
				var preferred := -1.0 if leader.lateral > 0 else 1.0
				for candidate in [preferred,-preferred]:
					if lane_clear(driver,candidate,leader.car):
						desired = candidate
						opponent = leader.car
						committed_s = 0
						attempts += 1
						state = "passing_inside" if desired < 0 else "passing_outside"
						break
	# Never cross through another car to return to the ideal line or change lanes.
	if desired != target_lane and not lane_clear(driver,desired,opponent):
		desired = target_lane
		state = "holding_lane"
	target_lane = desired
	# About 110 m per full blend; preview uses the same spatial transition.
	lane = move_toward(lane,target_lane,maxf(8,driver.car.speed_mps)*delta/110.0)
	if opponent == null and state == "clear" and absf(lane) > .01:
		state = "returning"

func lane_clear(driver, candidate: float, ignored: Node3D = null) -> bool:
	var destination := lane_lateral(driver,candidate,0)
	for other in nearby:
		if other.car == ignored and absf(other.gap) > 20:
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
	var preview := move_toward(lane,target_lane,maxf(0,distance)/110.0)
	return path_point(driver,distance,preview)

func planner_samples(driver, count: int) -> PackedVector3Array:
	var result := PackedVector3Array()
	result.resize(count)
	if not enabled or driver.mode != 2 or inside.size() != driver.race.size() or driver.race_length_m <= .001:
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
		var choice := move_toward(lane,target_lane,maxf(0,distance)/110.0)
		if absf(choice) >= .0001:
			var alternative := inside[low].lerp(inside[next],fraction) if choice < 0 else outside[low].lerp(outside[next],fraction)
			point = point.lerp(alternative,absf(choice))
		result[i] = point
		previous = at
	return result

func traffic_speed(driver, request: float) -> float:
	# A legal target does not guarantee the body stays on it. Shed speed early
	# when tracking error consumes the road-edge reserve, retaining lane priority.
	if absf(own.y) > road_edge_speed_start_m:
		request = minf(request,maxf(15,driver.car.speed_mps)*clampf(1.0-(absf(own.y)-road_edge_speed_start_m)*.15,.65,1.0))
		driver.traffic_reason = "road_edge"
	for other in nearby:
		if other.gap <= 0 or other.gap > maxf(15,driver.car.speed_mps*2):
			continue
		var intended := lane_lateral(driver,target_lane,other.gap)
		var separated: bool = absf(other.lateral-own.y) > 4.2 and absf(other.lateral-intended) > 4.2
		if separated:
			continue
		var following: float = maxf(0,other.car.speed_mps+(other.gap-9-maxf(0,driver.car.speed_mps)*.7)*.6)
		if following < request:
			request = following
			driver.traffic_reason = "following_"+str(other.car.name)
	return request
