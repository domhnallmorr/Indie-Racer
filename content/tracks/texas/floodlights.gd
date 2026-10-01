@tool
extends Node3D
## Unlit fixtures; roof brackets replace ground poles at the main grandstand.
const LAP := 2414.016
const SPACING := 30.0
const POLE_HEIGHT := 22.0
var mounts: Array[Dictionary] = []
var _builders: Dictionary = {}

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/texas/geometry.json"))
	var wall: Array = []
	for strip in data.strips:
		if strip.name == "OuterWall": wall = strip.rows
	if wall.is_empty(): return
	var stand = get_parent().get_node("FrontstretchGrandstand")
	for pair in [["GroundPoles","697579",.6],["RoofBrackets","697579",.6],["LampHousings","8c9698",.5],["LampFaces","d5dad4",.05],["ConcreteBases","999b91",.0]]:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(pair[1])
		material.metallic = pair[2]
		material.roughness = .55
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		builder.set_material(material)
		_builders[pair[0]] = builder
	var count := ceili(LAP/SPACING)
	for index in range(count):
		var s := (index+.5)*LAP/count
		var at := s/LAP*(wall.size()-1)
		var i := int(at)
		var inner := _v(wall[i][2]).lerp(_v(wall[i+1][2]),at-i)
		var outer := _v(wall[i][3]).lerp(_v(wall[i+1][3]),at-i)
		var outward := outer-inner
		outward.y = 0
		outward = outward.normalized()
		var on_roof: bool = s >= stand.START or s <= stand.END-LAP
		var base: Vector3
		var head: Vector3
		var steel_key := "RoofBrackets" if on_roof else "GroundPoles"
		if on_roof:
			base = stand._point(s,60.5,49.0)
			outward = (stand._point(s,61.5,49.0)-base).normalized()
			head = base+Vector3.UP*2.4
			_box("RoofBrackets",Transform3D.IDENTITY,base+Vector3.UP*.08,Vector3(.8,.16,.8))
			_pole(steel_key,base,head,.10,.075)
		else:
			base = (inner+outer)*.5+outward*3
			base.y = -.2
			head = Vector3(base.x,(inner.y+outer.y)*.5-1.25+POLE_HEIGHT,base.z)
			_box("ConcreteBases",Transform3D.IDENTITY,base+Vector3.UP*.35,Vector3(.75,.7,.75))
			_pole(steel_key,base+Vector3.UP*.5,head,.19,.09)
		var pose := Transform3D(Basis(Vector3.UP.cross(outward),Vector3.UP,outward),head)
		_box(steel_key,pose,Vector3.ZERO,Vector3(6.3,.15,.15))
		for side in [-1,1]:
			_pole(steel_key,head-Vector3.UP*.8,pose*Vector3(side*1.8,0,0),.035,.035)
		for lamp in range(6):
			var local := Vector3(-2.5+lamp,.1,-.16)
			var direction := Vector3(0,-.42,-.9075).normalized()
			var lamp_pose := pose*Transform3D(Basis(Quaternion(Vector3.UP,direction)),local)
			var housing := CylinderMesh.new()
			housing.top_radius = .38
			housing.bottom_radius = .21
			housing.height = .38
			housing.radial_segments = 12
			_append("LampHousings",housing,lamp_pose)
			var lens := CylinderMesh.new()
			lens.top_radius = .34
			lens.bottom_radius = .34
			lens.height = .025
			lens.radial_segments = 12
			_append("LampFaces",lens,lamp_pose*Transform3D(Basis.IDENTITY,Vector3(0,.205,0)))
		mounts.append({"distance":s,"roof":on_roof,"base":base,"head":head})
	for key in _builders:
		var mesh := MeshInstance3D.new()
		mesh.name = key
		mesh.mesh = _builders[key].commit()
		add_child(mesh)
	_builders.clear()

func _v(p: Array) -> Vector3:
	return Vector3(p[0],p[1],p[2])

func _append(key: String,primitive: PrimitiveMesh,pose: Transform3D) -> void:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,primitive.surface_get_arrays(0))
	_builders[key].append_from(mesh,0,pose)

func _box(key: String,pose: Transform3D,center: Vector3,size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	_append(key,box,pose*Transform3D(Basis.IDENTITY,center))

func _pole(key: String,a: Vector3,b: Vector3,bottom: float,top: float) -> void:
	var pole := CylinderMesh.new()
	pole.bottom_radius = bottom
	pole.top_radius = top
	pole.height = a.distance_to(b)
	pole.radial_segments = 10
	_append(key,pole,Transform3D(Basis(Quaternion(Vector3.UP,(b-a).normalized())),(a+b)*.5))
