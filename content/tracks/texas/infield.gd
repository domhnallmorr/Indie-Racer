@tool
extends Node3D
## Ground-only period-inspired layout: paddock, service roads and infield circuit.
const SURFACE = preload("res://content/tracks/texas/infield_surface.gdshader")
var _builders: Dictionary = {}

func _ready() -> void:
	_add_surface("DryInfieldGrass","677345","858457",0)
	_add_surface("PaddockConcrete","a3a29a","a3a29a",2)
	_add_surface("GarageAprons","b3a38a","b3a38a",2)
	_add_surface("ServiceAsphalt","626563","626563",3)
	_add_surface("RoadCourseAsphalt","444c50","444c50",3)
	_add_surface("ParkingPaint","c7c5ae","c7c5ae",3)
	_add_surface("RoadCourseEdges","c6c9c2","c6c9c2",3)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/texas/geometry.json"))
	var boundary := PackedVector2Array()
	for strip in data.strips:
		if strip.name == "Apron":
			for i in range(strip.rows.size()-1):
				var p: Array = strip.rows[i][-1]
				boundary.append(Vector2(p[0],p[2]))
	_polygon("DryInfieldGrass",boundary,-.18)
	# Broad service hardstanding behind pit road, tapering inside the oval ends.
	_polygon("PaddockConcrete",PackedVector2Array([
		Vector2(-325,50),Vector2(-290,125),Vector2(-220,171),Vector2(-150,190),
		Vector2(150,190),Vector2(230,169),Vector2(290,118),Vector2(320,50),
		Vector2(260,37),Vector2(-260,37)]),-.15)
	# Long central service road separates the working paddock from the circuit.
	_path("ServiceAsphalt",_curve([Vector2(-340,-8),Vector2(-300,22),Vector2(-170,28),Vector2(0,28),Vector2(175,28),Vector2(295,18),Vector2(335,-10)],false),9,-.11)
	for x in [-215.0,-65.0,85.0,235.0]:
		_path("ServiceAsphalt",PackedVector2Array([Vector2(x,30),Vector2(x,154)]),7,-.10)
	# Warm, rectangular garage/service pads; no buildings implied by the texture.
	for x in [-140.0,10.0,160.0]:
		_rect("GarageAprons",Vector2(x-54,53),Vector2(x+54,145),-.12)
		for z in [79.0,116.0]:
			_rect("ServiceAsphalt",Vector2(x-10,z),Vector2(x+48,z+9),-.09)
	# Transporter parking near either end of the paddock, with restrained paint.
	for x in [-268.0,265.0]:
		for z in range(60,117,8):
			_path("ParkingPaint",PackedVector2Array([Vector2(x-12,z),Vector2(x+12,z)]),.13,-.07)
		_path("ParkingPaint",PackedVector2Array([Vector2(x,60),Vector2(x,116)]),.13,-.07)
	# The backstraight half is a maintained road course, not abandoned paving.
	# This is a visual approximation of the supplied map, without racing AI/routes.
	var circuit := _curve([Vector2(-287,-62),Vector2(-310,-108),Vector2(-268,-150),
		Vector2(-150,-177),Vector2(0,-183),Vector2(165,-175),Vector2(276,-144),
		Vector2(305,-96),Vector2(272,-55),Vector2(212,-45),Vector2(155,-64),
		Vector2(92,-102),Vector2(35,-111),Vector2(-35,-81),Vector2(-125,-48),Vector2(-221,-43)],true)
	_road_edges(circuit)
	_path("RoadCourseAsphalt",circuit,12,-.10)
	# Access spurs join the service spine to the infield circuit.
	_path("ServiceAsphalt",_curve([Vector2(-242,25),Vector2(-258,-5),Vector2(-277,-39),Vector2(-287,-62)],false),7,-.08)
	_path("ServiceAsphalt",_curve([Vector2(239,25),Vector2(247,-9),Vector2(264,-35),Vector2(272,-55)],false),7,-.08)
	for key in _builders:
		var instance := MeshInstance3D.new()
		instance.name = key
		instance.mesh = _builders[key].commit()
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	_builders.clear()

func _add_surface(key: String,base: String,secondary: String,kind: int) -> void:
	var material := ShaderMaterial.new()
	material.shader = SURFACE
	material.set_shader_parameter("base_color",Color(base))
	material.set_shader_parameter("secondary_color",Color(secondary))
	material.set_shader_parameter("surface_kind",kind)
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(material)
	_builders[key] = builder

func _vertex(builder: SurfaceTool,p: Vector2,height: float) -> void:
	builder.set_normal(Vector3.UP)
	builder.set_uv(p)
	builder.add_vertex(Vector3(p.x,height,p.y))

func _polygon(key: String,points: PackedVector2Array,height: float) -> void:
	var indices := Geometry2D.triangulate_polygon(points)
	assert(not indices.is_empty(),"Invalid infield polygon")
	for i in indices: _vertex(_builders[key],points[i],height)

func _rect(key: String,a: Vector2,b: Vector2,height: float) -> void:
	_polygon(key,PackedVector2Array([a,Vector2(b.x,a.y),b,Vector2(a.x,b.y)]),height)

func _path(key: String,points: PackedVector2Array,width: float,height: float) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var closed := points[0].is_equal_approx(points[-1])
	for i in range(points.size()):
		var previous := points[points.size()-2] if closed and i==0 else points[maxi(0,i-1)]
		var next := points[1] if closed and i==points.size()-1 else points[mini(points.size()-1,i+1)]
		var tangent := (next-previous).normalized()
		var offset := Vector2(-tangent.y,tangent.x)*width*.5
		left.append(points[i]+offset)
		right.append(points[i]-offset)
	for i in range(points.size()-1):
		for p in [left[i],left[i+1],right[i+1],left[i],right[i+1],right[i]]:
			_vertex(_builders[key],p,height)

func _curve(points: Array,closed: bool) -> PackedVector2Array:
	var result := PackedVector2Array()
	var n := points.size()
	for i in range(n if closed else n-1):
		var a: Vector2 = points[(i-1+n)%n] if closed else points[maxi(0,i-1)]
		var b: Vector2 = points[i]
		var c: Vector2 = points[(i+1)%n]
		var d: Vector2 = points[(i+2)%n] if closed else points[mini(n-1,i+2)]
		var steps := maxi(4,ceili(b.distance_to(c)/3))
		for j in range(steps):
			var t := float(j)/steps
			result.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
	result.append(points[0] if closed else points[-1])
	return result

func _road_edges(points: PackedVector2Array) -> void:
	# Separate narrow ribbons avoid overlapping the asphalt at distant views.
	for side in [-1.0,1.0]:
		var edge := PackedVector2Array()
		for i in range(points.size()):
			var previous := points[points.size()-2] if i==0 else points[i-1]
			var next := points[1] if i==points.size()-1 else points[i+1]
			var tangent := (next-previous).normalized()
			edge.append(points[i]+Vector2(-tangent.y,tangent.x)*side*6.12)
		_path("RoadCourseEdges",edge,.20,-.10)

