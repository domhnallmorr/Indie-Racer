extends RefCounted
## Track-local coordinates; planar lane corridor plus the adjacent pit-box area.
var pit_boxes: Array = []
var pace_car_box := Transform3D.IDENTITY
var pit_path := PackedVector3Array()
var pit_box_area := PackedVector2Array()
var half_width := 5.0
var min_height := -0.5
var max_height := 2.5
var speed_zone := PackedVector2Array()
var speed_limit_kph := 80.0
var speed_exit_x := 195.0
var pit_sections: Array[Rect2] = []
var race_laps := 10
var pace_speed_kph := 80.0
var grid_origin := Vector3(150.0,0.025,-125.0)
var grid_heading_deg := 90.0
var grid_row_spacing_m := 8.0
var grid_lane_spacing_m := 5.0
var green_point := Vector3(-250.0,0.0,125.0)
var green_normal := Vector3.RIGHT
var path_based_pits := false
var reference_paths_file := "res://content/tracks/mile_oval/ai/reference_paths.json"
var limiter_pose := Transform3D.IDENTITY
var circuit_length_m := 1609.344
var _grid_road: Array = []
const PIT_SECTION_SEGMENTS := 20

func load_config(path: String) -> Error:
	_grid_road.clear()
	pit_boxes.clear()
	pit_path.clear()
	pit_box_area.clear()
	speed_zone.clear()
	pit_sections.clear()
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schema_version") != 1 or data.get("units") != "metres":
		return ERR_INVALID_DATA
	path_based_pits = bool(data.get("path_based_pits",false))
	reference_paths_file = path.get_base_dir()+"/ai/reference_paths.json"
	var race: Variant = data.get("race",{})
	if not race is Dictionary:
		return ERR_INVALID_DATA
	if not race.is_empty():
		if not _number(race.get("laps")) or int(race.laps) < 1 or not _number(race.get("pace_speed_kph")) or float(race.pace_speed_kph) <= 0:
			return ERR_INVALID_DATA
		var grid: Variant = race.get("grid")
		if not grid is Dictionary or not _numbers(grid.get("origin"),3) or not _number(grid.get("heading_deg")) or not _number(grid.get("row_spacing_m")) or not _number(grid.get("lane_spacing_m")):
			return ERR_INVALID_DATA
		if float(grid.row_spacing_m) <= 0 or float(grid.lane_spacing_m) <= 0 or not _numbers(race.get("green_point"),3):
			return ERR_INVALID_DATA
		race_laps = int(race.laps)
		pace_speed_kph = float(race.pace_speed_kph)
		grid_origin = Vector3(grid.origin[0],grid.origin[1],grid.origin[2])
		grid_heading_deg = float(grid.heading_deg)
		grid_row_spacing_m = float(grid.row_spacing_m)
		grid_lane_spacing_m = float(grid.lane_spacing_m)
		green_point = Vector3(race.green_point[0],race.green_point[1],race.green_point[2])
		if _numbers(race.get("green_normal"),3):
			green_normal = Vector3(race.green_normal[0],race.green_normal[1],race.green_normal[2]).normalized()
	var boxes = data.get("pit_boxes")
	var lane = data.get("pit_lane")
	if not boxes is Array or boxes.is_empty() or not lane is Dictionary:
		return ERR_INVALID_DATA
	var ids: Array = []
	for box in boxes:
		if not box is Dictionary or not box.get("id") is String or box.id.is_empty() or box.id in ids:
			return ERR_INVALID_DATA
		if not _numbers(box.get("position"), 3) or not _number(box.get("heading_deg")):
			return ERR_INVALID_DATA
		ids.append(box.id)
		pit_boxes.append(box)
	var pace_box: Variant = data.get("pace_car_box", {})
	if not pace_box is Dictionary or not _numbers(pace_box.get("position"),3) or not _number(pace_box.get("heading_deg")):
		return ERR_INVALID_DATA
	pace_car_box = Transform3D(Basis(Vector3.UP,deg_to_rad(pace_box.heading_deg)),Vector3(pace_box.position[0],pace_box.position[1],pace_box.position[2]))
	var relative = lane.get("path_file")
	if not relative is String or relative.is_absolute_path() or ".." in relative or ":" in relative:
		return ERR_INVALID_DATA
	var paths = JSON.parse_string(FileAccess.get_file_as_string(path.get_base_dir().path_join(relative)))
	if not paths is Dictionary or not paths.get("pit_path") is Array or paths.pit_path.size() < 2:
		return ERR_INVALID_DATA
	circuit_length_m = float(paths.get("reference_length_m",1609.344))
	for point in paths.pit_path:
		if not _numbers(point, 3):
			return ERR_INVALID_DATA
		pit_path.append(Vector3(point[0], point[1], point[2]))
	for field in ["half_width_m", "min_height_m", "max_height_m"]:
		if not _number(lane.get(field)):
			return ERR_INVALID_DATA
	half_width = lane.half_width_m
	min_height = lane.min_height_m
	max_height = lane.max_height_m
	if half_width <= 0 or min_height >= max_height:
		return ERR_INVALID_DATA
	var polygon = lane.get("pit_box_area_xz")
	if not polygon is Array or polygon.size() < 3:
		return ERR_INVALID_DATA
	for point in polygon:
		if not _numbers(point, 2):
			return ERR_INVALID_DATA
		pit_box_area.append(Vector2(point[0], point[1]))
	var speed = data.get("pit_speed_zone")
	if not speed is Dictionary or not _number(speed.get("limit_kph")) or not _number(speed.get("exit_line_x")):
		return ERR_INVALID_DATA
	if speed.limit_kph <= 0 or not speed.get("polygon_xz") is Array or speed.polygon_xz.size() < 3:
		return ERR_INVALID_DATA
	speed_limit_kph = speed.limit_kph
	speed_exit_x = speed.exit_line_x
	if path_based_pits:
		var pose: Dictionary = speed.get("exit_pose",{})
		if not _numbers(pose.get("position"),3) or not _number(pose.get("heading_deg")):
			return ERR_INVALID_DATA
		limiter_pose = Transform3D(Basis(Vector3.UP,deg_to_rad(pose.heading_deg)),Vector3(pose.position[0],pose.position[1],pose.position[2]))
	for point in speed.polygon_xz:
		if not _numbers(point, 2):
			return ERR_INVALID_DATA
		speed_zone.append(Vector2(point[0], point[1]))
	# Broad-phase groups avoid measuring every one of the pit path's segments
	# for every car, several times per physics tick. Exact distance stays decisive.
	for first in range(0,pit_path.size()-1,PIT_SECTION_SEGMENTS):
		var bounds := Rect2(Vector2(pit_path[first].x,pit_path[first].z),Vector2.ZERO)
		for i in range(first+1,mini(first+PIT_SECTION_SEGMENTS+1,pit_path.size())):
			bounds = bounds.expand(Vector2(pit_path[i].x,pit_path[i].z))
		pit_sections.append(bounds.grow(half_width+.001))
	# Generated tracks carry the same sampled road used by rendering/collision.
	# Read it before spawning; physics ray queries are not ready during _ready.
	var geometry_file := path.get_base_dir().path_join("geometry.json")
	if FileAccess.file_exists(geometry_file):
		var geometry = JSON.parse_string(FileAccess.get_file_as_string(geometry_file))
		if geometry is Dictionary:
			for strip in geometry.get("strips",[]):
				if strip.get("name","") == "RacingSurface":
					_grid_road = strip.rows
					break
	return OK

func in_green_zone(p: Vector3) -> bool:
	if not path_based_pits:
		return p.x >= green_point.x and p.z > 100.0
	var offset := p-green_point
	return offset.dot(green_normal) >= 0 and offset.dot(green_normal) < 180 and absf(offset.dot(green_normal.cross(Vector3.UP))) < 45

func nearest_pit_index(p: Vector3) -> int:
	var best := 0
	for i in range(1,pit_path.size()):
		if p.distance_squared_to(pit_path[i]) < p.distance_squared_to(pit_path[best]):
			best = i
	return best

func pit_approach_index(p: Vector3, before_m: float = 35.0) -> int:
	var at := nearest_pit_index(p)
	var distance := 0.0
	while at > 0 and distance < before_m:
		distance += pit_path[at].distance_to(pit_path[at-1])
		at -= 1
	return at

func contains_speed_limit_zone(local_position: Vector3) -> bool:
	return Geometry2D.is_point_in_polygon(Vector2(local_position.x, local_position.z), speed_zone) and contains_pit_lane(local_position)

func pit_box_transform(index: int = 0) -> Transform3D:
	var box: Dictionary = pit_boxes[index]
	var p: Array = box.position
	return Transform3D(Basis(Vector3.UP, deg_to_rad(box.heading_deg)), Vector3(p[0], p[1], p[2]))

func grid_transform(index: int) -> Transform3D:
	var basis := Basis(Vector3.UP,deg_to_rad(grid_heading_deg))
	var forward := -basis.z
	var right := basis.x
	var row := index / 2
	var side := -0.5 if index % 2 == 0 else 0.5
	var position := grid_origin-forward*row*grid_row_spacing_m+right*side*grid_lane_spacing_m
	if not _grid_road.is_empty():
		# Physics bodies stay upright. Clear the uphill edge of the 1.85 x 4.35 m
		# chassis, then let the existing tyre-grounding code settle the visual.
		var height := -INF
		for x in [-1.0,1.0]:
			for z in [-2.3,2.3]:
				height = maxf(height,_grid_surface_height(position+basis*Vector3(x,0,z)))
		if is_finite(height): position.y = height+.025
	return Transform3D(basis,position)

func _grid_surface_height(p: Vector3) -> float:
	var point := Vector2(p.x,p.z)
	for i in range(_grid_road.size()-1):
		var row: Array = _grid_road[i]
		var next: Array = _grid_road[i+1]
		var bounds := Rect2(Vector2(row[0][0],row[0][2]),Vector2.ZERO)
		for corner in [row[-1],next[0],next[-1]]:
			bounds = bounds.expand(Vector2(corner[0],corner[2]))
		if not bounds.grow(.001).has_point(point): continue
		for j in range(row.size()-1):
			for triangle in [[row[j],next[j+1],next[j]],[row[j],row[j+1],next[j+1]]]:
				var a := Vector3(triangle[0][0],triangle[0][1],triangle[0][2])
				var b := Vector3(triangle[1][0],triangle[1][1],triangle[1][2])
				var c := Vector3(triangle[2][0],triangle[2][1],triangle[2][2])
				if Geometry2D.is_point_in_polygon(point,PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])):
					var normal := (b-a).cross(c-a)
					return a.y-(normal.x*(p.x-a.x)+normal.z*(p.z-a.z))/normal.y
	return -INF

func contains_pit_lane(local_position: Vector3) -> bool:
	if local_position.y < min_height or local_position.y > max_height:
		return false
	var point := Vector2(local_position.x, local_position.z)
	if Geometry2D.is_point_in_polygon(point, pit_box_area):
		return true
	# Keep the uncached path usable by small programmatic track fixtures.
	if pit_sections.is_empty():
		return _contains_path_range(point,0,pit_path.size()-1)
	for section in range(pit_sections.size()):
		if pit_sections[section].has_point(point) and _contains_path_range(point,section*PIT_SECTION_SEGMENTS,mini((section+1)*PIT_SECTION_SEGMENTS,pit_path.size()-1)):
			return true
	return false

func _contains_path_range(point: Vector2, first: int, end: int) -> bool:
	for i in range(first,end):
		var a := Vector2(pit_path[i].x, pit_path[i].z)
		var b := Vector2(pit_path[i+1].x, pit_path[i+1].z)
		var nearest := Geometry2D.get_closest_point_to_segment(point, a, b)
		if point.distance_squared_to(nearest) <= half_width * half_width:
			return true
	return false

func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func _numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for number in value:
		if not _number(number):
			return false
	return true
