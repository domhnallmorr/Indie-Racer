@tool
extends Node3D
## Photo-inspired turn-2 building, with cream podium and glazed upper floors.
const LAP := 2414.016
const LOCATION := 920.0
const WIDTH := 150.0
const DEPTH := 24.0
const OVERALL_WIDTH := 130.0
var _builders: Dictionary = {}

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/texas/geometry.json"))
	var road: Array = []
	for strip in data.strips:
		if strip.name == "RacingSurface": road = strip.rows
	if road.is_empty(): return
	var at := LOCATION/LAP*(road.size()-1)
	var i := int(at)
	var outer := _v(road[i][0]).lerp(_v(road[i+1][0]),at-i)
	var inner := _v(road[i][-1]).lerp(_v(road[i+1][-1]),at-i)
	var outward := outer-inner
	outward.y = 0
	outward = outward.normalized()
	basis = Basis(Vector3.UP.cross(outward),Vector3.UP,outward)
	# Original facade plus two end towers spans 158.2 m including trim; resize the complete model.
	scale.x = OVERALL_WIDTH/158.2
	position = outer+outward*30
	position.y = -.2
	for pair in [["CreamConcrete","c7c4b4",.0],["WindowFrames","c7cecc",.25],["DarkGlass","203b48",.35],["BalconyTrim","8e4341",.25],["BlueRoofs","354f69",.3]]:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(pair[1])
		mat.metallic = pair[2]
		mat.roughness = .3 if pair[0] == "DarkGlass" else .8
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		builder.set_material(mat)
		_builders[pair[0]] = builder
	_box("CreamConcrete",Vector3(0,24,12),Vector3(WIDTH,48,DEPTH))
	# Square windows and subtle panel seams across the four-storey podium.
	for floor_index in range(4):
		var h := 2.8+floor_index*4.5
		for col in range(30):
			var x := -72.5+col*5
			_box("WindowFrames",Vector3(x,h,-.09),Vector3(2.0,2.2,.20))
			_box("DarkGlass",Vector3(x,h,-.21),Vector3(1.6,1.8,.08))
		_box("WindowFrames",Vector3(0,h+2.1,-.08),Vector3(WIDTH,.12,.15))
	for col in range(31):
		_box("WindowFrames",Vector3(-75+col*5,10,-.08),Vector3(.10,20,.15))
	# Six uninterrupted dark-glass levels with closely spaced mullions.
	_box("DarkGlass",Vector3(0,34,-.14),Vector3(WIDTH-4,27,.18))
	for floor_index in range(7):
		var h := 20.5+floor_index*4.5
		_box("WindowFrames",Vector3(0,h,-.30),Vector3(WIDTH,.30,.30))
	for col in range(73):
		_box("WindowFrames",Vector3(-72+col*2,34,-.32),Vector3(.13,27,.32))
	for floor_index in range(6):
		_box("WindowFrames",Vector3(0,21.8+floor_index*4.5,-.33),Vector3(WIDTH-4,.09,.24))
	# Long red-railed balcony where the podium meets the glazed facade.
	_box("CreamConcrete",Vector3(0,20,-1.05),Vector3(WIDTH+1,.35,2.1))
	_box("BalconyTrim",Vector3(0,20.28,-2.08),Vector3(WIDTH+1,.45,.13))
	_box("BalconyTrim",Vector3(0,21.15,-2.08),Vector3(WIDTH+1,.09,.09))
	for col in range(101):
		_box("WindowFrames",Vector3(-75+col*1.5,20.75,-2.08),Vector3(.045,.8,.045))
	# End service towers and small stacked side balconies.
	for side in [-1,1]:
		_box("CreamConcrete",Vector3(side*77,25,12),Vector3(4,50,DEPTH))
		for level in range(6):
			var h := 21.5+level*4.5
			_box("CreamConcrete",Vector3(side*77,h,-1.1),Vector3(4.2,.25,2.3))
			_box("BalconyTrim",Vector3(side*77,h+.65,-2.2),Vector3(4.2,.65,.1))
		for level in range(10):
			_box("WindowFrames",Vector3(side*79.05,2+level*4.8,12),Vector3(.1,.12,DEPTH))
	# Flat roof parapet, small blue-roofed dormers, and the large central gable.
	_box("WindowFrames",Vector3(0,48.2,12),Vector3(WIDTH+1,.45,DEPTH+1))
	for z in [0,24]:
		_box("CreamConcrete",Vector3(0,48.9,z),Vector3(WIDTH,.9,.25))
		_box("WindowFrames",Vector3(0,49.65,z),Vector3(WIDTH,.07,.07))
		for col in range(51):
			_box("WindowFrames",Vector3(-75+col*3,49.3,z),Vector3(.05,.7,.05))
	_gable(0,49,8,25,14,10)
	for x in [-61.0,-40.0,-21.0,24.0,43.0,62.0]:
		_box("CreamConcrete",Vector3(x,50.1,3),Vector3(4.6,2.8,4))
		_gable(x,51.5,.7,5.2,4.6,1.5)
	for key in _builders:
		var mesh := MeshInstance3D.new()
		mesh.name = key
		mesh.mesh = _builders[key].commit()
		add_child(mesh)
	_builders.clear()

func _v(p: Array) -> Vector3:
	return Vector3(p[0],p[1],p[2])

func _box(key: String,center: Vector3,size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,box.surface_get_arrays(0))
	_builders[key].append_from(mesh,0,Transform3D(Basis.IDENTITY,center))

func _triangle(key: String,a: Vector3,b: Vector3,c: Vector3) -> void:
	var builder: SurfaceTool = _builders[key]
	var normal := (b-a).cross(c-a).normalized()
	for p in [a,b,c]:
		builder.set_normal(normal)
		builder.add_vertex(p)

func _gable(x: float,y: float,z: float,width: float,depth: float,height: float) -> void:
	var a := Vector3(x-width*.5,y,z)
	var b := Vector3(x+width*.5,y,z)
	var peak := Vector3(x,y+height,z)
	var rear := Vector3(0,0,depth)
	_triangle("CreamConcrete",a,peak,b)
	_triangle("CreamConcrete",a+rear,b+rear,peak+rear)
	_triangle("BlueRoofs",a,a+rear,peak)
	_triangle("BlueRoofs",peak,a+rear,peak+rear)
	_triangle("BlueRoofs",peak,peak+rear,b)
	_triangle("BlueRoofs",b,peak+rear,b+rear)


