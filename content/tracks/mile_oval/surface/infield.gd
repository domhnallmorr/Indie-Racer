@tool
extends Node3D
## Visual approximation of the supplied overhead photograph, in track-local metres.
## Front straight / main grandstand is +Z. All paving stays inside the inner wall.

func _ready() -> void:
	var concrete := _material(Color(0.52,0.51,0.46),true)
	var asphalt := _material(Color(0.29,0.30,0.29),false)
	var access := _material(Color(0.40,0.40,0.36),false)
	var edge := _material(Color(0.61,0.60,0.52),false)
	_polygon("ConcretePaddock", PackedVector2Array([
		Vector2(-196,76),Vector2(124,76),Vector2(124,18),
		Vector2(99,1),Vector2(-163,1),Vector2(-196,14)
	]),0.012,concrete)
	# A sinuous spine and long back-side return, with a tight southern hairpin.
	var course := [
		Vector2(244,29),Vector2(232,21),Vector2(207,30),Vector2(177,25),Vector2(147,9),
		Vector2(121,-21),Vector2(79,-48),Vector2(28,-64),
		Vector2(-58,-65),Vector2(-158,-63),Vector2(-206,-53),
		Vector2(-231,-32),Vector2(-230,-16),Vector2(-214,-10),
		Vector2(-183,-18),Vector2(-145,-27),Vector2(-65,-29),
		Vector2(4,-28),Vector2(65,-18),Vector2(114,4),
		Vector2(145,33),Vector2(173,48),Vector2(207,56),Vector2(237,47)
	]
	var smooth := _smooth(course,true)
	_road("CourseShoulder",smooth,10.8,0.022,edge,true)
	_road("InfieldRoadCourse",smooth,9.0,0.032,asphalt,true)
	_road("NorthPaddockAccess",[Vector2(125,81),Vector2(125,41),Vector2(124,18),Vector2(114,4)],7.0,0.042,access)
	_road("PaddockServiceLane",[Vector2(-182,13),Vector2(-96,13),Vector2(10,13),Vector2(99,13),Vector2(124,18)],6.0,0.044,access)
	_road("CentralCrossAccess",[Vector2(68,75),Vector2(68,30),Vector2(65,-18),Vector2(65,-48),Vector2(65,-81)],6.0,0.046,access)
	_road("SouthCrossAccess",[Vector2(-106,11),Vector2(-106,-9),Vector2(-94,-28),Vector2(-94,-65),Vector2(-94,-81)],5.5,0.048,access)
	_road("CourseShortLink",[Vector2(5,-28),Vector2(5,-64)],7.0,0.050,asphalt)
	_road("SouthServiceSpur",_smooth([Vector2(-177,12),Vector2(-208,15),Vector2(-241,10),Vector2(-265,0)],false),5.0,0.052,access)
	_road("NorthServiceSpur",_smooth([Vector2(175,48),Vector2(213,62),Vector2(241,51),Vector2(269,23)],false),5.0,0.054,access)

func _material(color: Color, concrete: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://content/tracks/mile_oval/surface/infield.gdshader")
	mat.set_shader_parameter("base_color",Vector3(color.r,color.g,color.b))
	mat.set_shader_parameter("concrete",concrete)
	return mat

func _polygon(label: String, points: PackedVector2Array, height: float, material: Material) -> void:
	var indices := Geometry2D.triangulate_polygon(points)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,indices.size(),3):
		var a := points[indices[i]]
		var b := points[indices[i+1]]
		var c := points[indices[i+2]]
		_triangle(surface,a,b,c,height)
	_finish(label,surface,material)

func _triangle(surface: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, height: float) -> void:
	# Godot front faces use clockwise winding, viewed from above.
	var points := [a,b,c] if (b-a).cross(c-a) > 0.0 else [a,c,b]
	for p in points:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(p.x,height,p.y))

func _road(label: String, points: Array, width: float, height: float, material: Material, closed: bool = false) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: Array[Vector2] = []
	for i in range(points.size()):
		var before: Vector2 = points[(i-1+points.size())%points.size()] if closed or i>0 else points[i]
		var after: Vector2 = points[(i+1)%points.size()] if closed or i<points.size()-1 else points[i]
		var tangent := (after-before).normalized()
		sides.append(Vector2(-tangent.y,tangent.x)*width*0.5)
	for i in range(points.size() if closed else points.size()-1):
		var j := (i+1)%points.size()
		_triangle(surface,points[i]-sides[i],points[i]+sides[i],points[j]-sides[j],height)
		_triangle(surface,points[i]+sides[i],points[j]+sides[j],points[j]-sides[j],height)
	_finish(label,surface,material)

func _smooth(points: Array, closed: bool) -> Array:
	var result: Array = []
	var count := points.size()
	for i in range(count if closed else count-1):
		var a: Vector2 = points[(i-1+count)%count] if closed else points[maxi(i-1,0)]
		var b: Vector2 = points[i]
		var c: Vector2 = points[(i+1)%count]
		var d: Vector2 = points[(i+2)%count] if closed else points[mini(i+2,count-1)]
		for step in range(12):
			var t := float(step)/12.0
			result.append(0.5*((2.0*b)+(-a+c)*t+(2.0*a-5.0*b+4.0*c-d)*t*t+(-a+3.0*b-3.0*c+d)*t*t*t))
	if not closed:
		result.append(points[-1])
	return result

func _finish(label: String, surface: SurfaceTool, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = surface.commit()
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

