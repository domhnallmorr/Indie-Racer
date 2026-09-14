@tool
extends Node3D
## Approximation from the supplied 2002 race screenshot, not a surveyed 1995 model.
const CENTER_X := ((1609.344 - TAU * 125.0) / 2.0) * .15
const CROWD = preload("res://content/tracks/mile_oval/grandstands/crowd_support_atlas.png")

func _ready() -> void:
	position.x = CENTER_X
	var steel := _color(Color("aaa99e"))
	var roof := _color(Color("797d78"))
	var underside := _color(Color("555d58"))
	var cream := _color(Color("c8c5b2"))
	var glass := _color(Color("354945"))
	var aisle := _color(Color("888b83"))
	# Original seven concrete seating rows remain underneath the crowd surface.
	var crowd_mat := StandardMaterial3D.new()
	crowd_mat.albedo_texture = CROWD
	crowd_mat.uv1_scale = Vector3(1,.49,1)
	crowd_mat.uv1_offset = Vector3(0,.003,0)
	crowd_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	crowd_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	crowd_mat.albedo_color = Color(.9,.9,.9)
	for i in range(10):
		var x := -130.0 + 26.0 * i
		_slope("CrowdBay%d" % i,x+1,24,crowd_mat)
		_slope("Aisle%d" % i,x,1,aisle)
	_slope("EndAisle",129,1,aisle)
	# Shallow full-width canopy, slightly higher at the rear.
	var canopy := _box("Roof",Vector3(264,.4,28),Vector3(0,15,159.5),roof)
	canopy.rotation.x = deg_to_rad(2.0)
	_box("FrontFascia",Vector3(264,.65,.22),Vector3(0,14.5,145.5),cream)
	_box("RearFascia",Vector3(264,.55,.22),Vector3(0,15.2,173.5),steel)
	for i in range(14):
		var x := -130.0 + 20.0*i
		_box("FrontPillar%d" % i,Vector3(.28,14.2,.28),Vector3(x,7.1,150),steel)
		_box("RearPillar%d" % i,Vector3(.3,14.9,.3),Vector3(x,7.45,170),steel)
		_box("RoofRafter%d" % i,Vector3(.22,.3,27),Vector3(x,14.65,159.5),underside)
		_beam(Vector3(x,11.9,150),Vector3(x,14.6,146),steel)
		_beam(Vector3(x,11.9,150),Vector3(x,14.8,154),steel)
	# Windowed press/commentary enclosure suspended beneath the central canopy.
	_box("CommentaryBooths",Vector3(76,2.6,4.5),Vector3(0,12.85,150),cream)
	_box("BoothFloor",Vector3(77,.25,4.9),Vector3(0,11.45,150),steel)
	_box("BoothHeader",Vector3(76,.25,.18),Vector3(0,14.05,147.65),cream)
	for i in range(19):
		var x := -36.0 + 4.0*i
		_box("BoothWindow%d" % i,Vector3(3.65,1.6,.06),Vector3(x,12.95,147.71),glass)
		_box("WindowMullion%d" % i,Vector3(.09,1.65,.12),Vector3(x,12.95,147.64),steel)
	for x in [-38.03,38.03]:
		_box("BoothSideWindow",Vector3(.06,1.6,3.7),Vector3(x,12.95,150),glass)
	_box("RearScreen",Vector3(260,7,.18),Vector3(0,10.4,169),underside)

func _color(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = .95
	return mat

func _box(label: String,size: Vector3,pos: Vector3,mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	add_child(instance)
	return instance

func _beam(a: Vector3,b: Vector3,mat: Material) -> void:
	var instance := _box("RoofBrace",Vector3(.16,a.distance_to(b),.16),(a+b)/2,mat)
	var axis := (b-a).normalized()
	var side := Vector3.RIGHT
	instance.basis = Basis(side,axis,side.cross(axis))

func _slope(label: String,x: float,width: float,mat: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(mat)
	var verts := [Vector3(x,2.0,147.5),Vector3(x,7.5,168.5),Vector3(x+width,2.0,147.5),Vector3(x+width,7.5,168.5)]
	var uvs := [Vector2(0,1),Vector2(0,0),Vector2(1,1),Vector2(1,0)]
	for idx in [0,1,2,2,1,3]:
		surface.set_uv(uvs[idx])
		surface.add_vertex(verts[idx])
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = surface.commit()
	add_child(instance)

