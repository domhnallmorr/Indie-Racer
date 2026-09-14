extends RefCounted
## Track-local coordinates; planar lane corridor plus the adjacent pit-box area.
var pit_boxes: Array = []
var pit_path := PackedVector3Array()
var pit_box_area := PackedVector2Array()
var half_width := 5.0
var min_height := -0.5
var max_height := 2.5
var speed_zone := PackedVector2Array()
var speed_limit_kph := 80.0
var speed_exit_x := 195.0
var pit_sections: Array[Rect2] = []
const PIT_SECTION_SEGMENTS := 20

func load_config(path: String) -> Error:
	pit_boxes.clear()
	pit_path.clear()
	pit_box_area.clear()
	speed_zone.clear()
	pit_sections.clear()
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schema_version") != 1 or data.get("units") != "metres":
		return ERR_INVALID_DATA
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
	var relative = lane.get("path_file")
	if not relative is String or relative.is_absolute_path() or ".." in relative or ":" in relative:
		return ERR_INVALID_DATA
	var paths = JSON.parse_string(FileAccess.get_file_as_string(path.get_base_dir().path_join(relative)))
	if not paths is Dictionary or not paths.get("pit_path") is Array or paths.pit_path.size() < 2:
		return ERR_INVALID_DATA
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
	return OK

func contains_speed_limit_zone(local_position: Vector3) -> bool:
	return Geometry2D.is_point_in_polygon(Vector2(local_position.x, local_position.z), speed_zone) and contains_pit_lane(local_position)

func pit_box_transform(index: int = 0) -> Transform3D:
	var box: Dictionary = pit_boxes[index]
	var p: Array = box.position
	return Transform3D(Basis(Vector3.UP, deg_to_rad(box.heading_deg)), Vector3(p[0], p[1], p[2]))

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
