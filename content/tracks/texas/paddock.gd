@tool
extends Node3D
## Period-inspired paddock scenery. Fixed placements keep access lanes open.
const TRUCK = preload("res://content/tracks/mile_oval/transporters/transporters.gd")
const PAINT := ["b74438","304d75","dfbc50","42725a","d3d3c7","654e79"]
var _surface: SurfaceTool

func _ready() -> void:
	_surface = _builder()
	for x in [-140.0,10.0,160.0]:
		_garage(Vector3(x-32,-.12,99))
	var buildings := MeshInstance3D.new()
	buildings.name = "GarageBlocks"
	buildings.mesh = _surface.commit()
	add_child(buildings)
	var factory = TRUCK.new()
	var truck_mesh: ArrayMesh = factory._make_truck()
	factory.free()
	var trucks: Array[Transform3D] = []
	for x in [-140.0,10.0,160.0]:
		for dx in [1.0,15.0,29.0,43.0]:
			for z in [66.0,99.0,136.0]:
				trucks.append(Transform3D(Basis.IDENTITY,Vector3(x+dx,-.12,z)))
	_batch("TeamTransporters",truck_mesh,trucks,true)
	for variant in range(3):
		_surface = _builder()
		_motorhome(variant)
		var camper_mesh := _surface.commit()
		var campers: Array[Transform3D] = []
		for row in range(3):
			for slot in range(19):
				if (slot+row*2)%3 != variant or (slot+row*3)%7 == 0: continue
				var x := -198.0+slot*22.0
				var z := -12.0 if row == 0 else (-140.0 if row == 1 else -157.0)
				# Back rows stay between the two arms of the infield circuit.
				if row > 0 and absf(x)>155: continue
				var yaw := PI if row == 2 else 0.0
				campers.append(Transform3D(Basis(Vector3.UP,yaw),Vector3(x,-.18,z)))
		_batch("Motorhomes%d" % variant,camper_mesh,campers,false)
	_surface = null

func _builder() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = .85
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.set_material(material)
	return surface

func _batch(label: String,mesh: ArrayMesh,poses: Array[Transform3D],painted: bool) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = painted
	multi.mesh = mesh
	multi.instance_count = poses.size()
	for i in range(poses.size()):
		multi.set_instance_transform(i,poses[i])
		if painted: multi.set_instance_custom_data(i,Color(PAINT[i%PAINT.size()]).srgb_to_linear())
	var batch := MultiMeshInstance3D.new()
	batch.name = label
	batch.multimesh = multi
	add_child(batch)

func _box(center: Vector3,size: Vector3,color: String) -> void:
	var box := BoxMesh.new()
	box.size = size
	_primitive(box,Transform3D(Basis.IDENTITY,center),Color(color))

func _primitive(mesh: PrimitiveMesh,pose: Transform3D,color: Color) -> void:
	var arrays := mesh.surface_get_arrays(0)
	for i in arrays[Mesh.ARRAY_INDEX]:
		_surface.set_color(color.srgb_to_linear())
		_surface.set_normal(pose.basis*arrays[Mesh.ARRAY_NORMAL][i])
		_surface.add_vertex(pose*arrays[Mesh.ARRAY_VERTEX][i])

func _triangle(a: Vector3,b: Vector3,c: Vector3,color: String) -> void:
	for p in [a,b,c]:
		_surface.set_color(Color(color).srgb_to_linear())
		_surface.set_normal((b-a).cross(c-a).normalized())
		_surface.add_vertex(p)

func _garage(p: Vector3) -> void:
	_box(p+Vector3(0,2.4,0),Vector3(22,4.8,78),"c9bfaa")
	for side in [-1.0,1.0]:
		for bay in range(12):
			var z := -35.75+bay*6.5
			_box(p+Vector3(side*11.03,1.9,z),Vector3(.08,3.8,5.3),"373d3d")
			_box(p+Vector3(side*11.09,3.8,z),Vector3(.12,.18,5.7),"eee4ca")
			_box(p+Vector3(side*11.09,1.9,z-2.7),Vector3(.14,3.8,.12),"eee4ca")
		_box(p+Vector3(side*11.35,4.65,0),Vector3(.16,.2,80),"e0d4b9")
	var a := p+Vector3(-11.6,4.8,-40)
	var b := p+Vector3(11.6,4.8,-40)
	var peak := p+Vector3(0,7,-40)
	var rear := Vector3(0,0,80)
	_triangle(a,peak,b,"c9bfaa")
	_triangle(a+rear,b+rear,peak+rear,"c9bfaa")
	_triangle(a,a+rear,peak,"a18a68")
	_triangle(peak,a+rear,peak+rear,"a18a68")
	_triangle(peak,peak+rear,b,"b09a78")
	_triangle(b,peak+rear,b+rear,"b09a78")
	for end in [-1.0,1.0]:
		for panel in range(3):
			_box(p+Vector3(-7.2+panel*7.2,3.25,end*39.08),Vector3(7.1,1.65,.1),["344c70","e2dfd1","a74b41"][panel])
		_box(p+Vector3(0,1.2,end*39.1),Vector3(2.2,2.4,.13),"555b57")

func _motorhome(variant: int) -> void:
	var length := 8.5+variant*.9
	_box(Vector3(0,1.9,0),Vector3(2.65,2.7,length),"e0ded1")
	_box(Vector3(0,.64,0),Vector3(2.4,.3,length),"454944")
	_box(Vector3(0,3.3,0),Vector3(2.7,.14,length+.08),"ece8dc")
	_box(Vector3(0,2.35,-length*.5-.025),Vector3(2.35,1.05,.06),"263d49")
	_box(Vector3(0,1,-length*.5-.06),Vector3(2.55,.2,.14),"b9b9ae")
	for side in [-1.0,1.0]:
		_box(Vector3(side*1.335,1.35,0),Vector3(.04,.36,length),PAINT[variant+1])
		for z in [-2.6,0.0,2.6]:
			_box(Vector3(side*1.34,2.4,z),Vector3(.05,.78,1.5),"30444a")
		for z in [-length*.31,length*.3]:
			var tyre := CylinderMesh.new()
			tyre.top_radius = .48
			tyre.bottom_radius = .48
			tyre.height = .24
			tyre.radial_segments = 10
			_primitive(tyre,Transform3D(Basis(Vector3.FORWARD,PI*.5),Vector3(side*1.25,.48,z)),Color("292c2d"))
	for z in [-2.0,2.0]:
		_box(Vector3(0,3.53,z),Vector3(.85,.36,.95),"c4c5bc")
	if variant != 1:
		_box(Vector3(2.7,2.6,.6),Vector3(2.8,.09,5.7),PAINT[variant+1])
		for z in [-2.1,3.3]:
			_box(Vector3(4.04,1.3,z),Vector3(.06,2.6,.06),"bbbdaf")
