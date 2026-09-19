@tool
extends Node3D
## Entry markings follow the limiter boundary; the apron joins pit lane to box 1.
const SessionData = preload("res://game/race/track_session_data.gd")
const APPROACH := [
	Vector2(-125,104),Vector2(-112,89.5),Vector2(-90.98646,89.5),
	Vector2(-90.98646,96.005),Vector2(-105,99),
]
var entry_x := -130.0
var entry_inner_z := 100.0
const WALL_Z := 108.0
const ORIGINAL_WALL_START_X := 125.0-(1609.344-TAU*125.0)/4.0

func _ready() -> void:
	var data = SessionData.new()
	if data.load_config("res://content/tracks/mile_oval/session.json") != OK:
		return
	entry_x = data.speed_zone[0].x
	for point in data.speed_zone:
		entry_x = minf(entry_x,point.x)
	for i in range(data.pit_path.size()-1):
		var a: Vector3 = data.pit_path[i]
		var b: Vector3 = data.pit_path[i+1]
		if a.x <= entry_x and b.x > entry_x:
			entry_inner_z = lerpf(a.z,b.z,(entry_x-a.x)/(b.x-a.x))-data.half_width
			break
	var marking_center_z := (entry_inner_z+WALL_Z-.3)*.5
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("ffe04a")
	paint.roughness = 1.0
	var line := MeshInstance3D.new()
	line.name = "LimiterEntryLine"
	var plane := PlaneMesh.new()
	plane.size = Vector2(.65,WALL_Z-.3-entry_inner_z)
	line.mesh = plane
	line.material_override = paint
	line.position = Vector3(entry_x,.026,marking_center_z)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)
	var number := Label3D.new()
	number.name = "RoadSpeedMarking"
	number.text = str(int(data.speed_limit_kph))
	number.font_size = 128
	number.pixel_size = .022
	number.modulate = paint.albedo_color
	number.outline_size = 0
	number.rotation = Vector3(-PI/2,-PI/2,0)
	number.position = Vector3(entry_x-3.5,.028,marking_center_z+.6)
	add_child(number)
	var sign := Label3D.new()
	sign.name = "LimiterEntrySign"
	sign.text = "PIT LIMIT\n%d km/h" % int(data.speed_limit_kph)
	sign.font_size = 64
	sign.pixel_size = .012
	sign.modulate = paint.albedo_color
	sign.position = Vector3(entry_x,2.0,entry_inner_z-2.0)
	sign.rotation.y = -PI/2
	add_child(sign)
	_build_approach()
	_build_separator_extension()

func _build_separator_extension() -> void:
	if entry_x >= ORIGINAL_WALL_START_X:
		return
	var wall := MeshInstance3D.new()
	wall.name = "PitSeparatorExtension"
	var box := BoxMesh.new()
	box.size = Vector3(ORIGINAL_WALL_START_X-entry_x,1.0,.5)
	wall.mesh = box
	wall.position = Vector3((entry_x+ORIGINAL_WALL_START_X)*.5,.5,WALL_Z)
	wall.material_override = get_parent().get_node("TrackSurface").wall_materials[0]
	add_child(wall)
	wall.create_trimesh_collision()

func _build_approach() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(PackedVector2Array(APPROACH))
	for i in range(0,indices.size(),3):
		var a: Vector2 = APPROACH[indices[i]]
		var b: Vector2 = APPROACH[indices[i+1]]
		var c: Vector2 = APPROACH[indices[i+2]]
		for point in ([a,b,c] if (b-a).cross(c-a) > 0 else [a,c,b]):
			surface.set_normal(Vector3.UP)
			surface.add_vertex(Vector3(point.x,.004,point.y))
	var apron := MeshInstance3D.new()
	apron.name = "PitAccessAsphalt"
	apron.mesh = surface.commit()
	apron.material_override = get_parent().get_node("TrackSurface").material
	add_child(apron)
	# Below pit-lane pavement (.008 m), flush with the concrete stall edge.
	# This replaces grass grip as well as its appearance.
	apron.create_trimesh_collision()
