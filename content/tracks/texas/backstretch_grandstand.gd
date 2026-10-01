@tool
extends Node3D
## Empty, roofless backstretch bleachers based on the supplied period reference.
const LAP := 2414.016
const START := 1027.0
const END := 1387.0
const BAYS := 18
const ROWS := 20
var _builders: Dictionary = {}

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/texas/geometry.json"))
	var road: Array = []
	for strip in data.strips:
		if strip.name == "RacingSurface": road = strip.rows
	if road.is_empty(): return
	for pair in [["AluminiumBenches","b8bdbb",.55],["DeckAndStairs","7e8585",.35],["SupportSteel","465354",.55]]:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(pair[1])
		material.metallic = pair[2]
		material.roughness = .7
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		builder.set_material(material)
		_builders[pair[0]] = builder
	var width := (END-START)/BAYS
	for bay in range(BAYS):
		var s := START+(bay+.5)*width
		var at := s/LAP*(road.size()-1)
		var i := int(at)
		var outside := _v(road[i][0]).lerp(_v(road[i+1][0]),at-i)
		var inside := _v(road[i][-1]).lerp(_v(road[i+1][-1]),at-i)
		var outward := outside-inside
		outward.y = 0
		outward = outward.normalized()
		var tangent := Vector3.UP.cross(outward)
		var pose := Transform3D(Basis(tangent,Vector3.UP,outward),outside+outward*6)
		for row in range(ROWS):
			var depth := row*.82
			var height := 1.0+row*.38
			_box("DeckAndStairs",pose,Vector3(0,height,depth+.41),Vector3(width,.12,.82))
			# Raised bare aluminium bench slats; no spectators or crowd materials.
			_box("AluminiumBenches",pose,Vector3(.65,height+.42,depth+.56),Vector3(width-1.7,.10,.34))
			for x in [-width*.3,0,width*.3]:
				_box("SupportSteel",pose,Vector3(x,height+.20,depth+.56),Vector3(.065,.4,.16))
			# Two shallow steps per seating row form a clear aisle at each bay join.
			for step in range(2):
				_box("DeckAndStairs",pose,Vector3(-width*.5+.65,height-.19+step*.19,depth+.205+step*.41),Vector3(1.3,.18,.41))
		# Open rear walkway, railing and grounded structural legs.
		var rear_height := 1.0+(ROWS-1)*.38
		_box("DeckAndStairs",pose,Vector3(0,rear_height,17.2),Vector3(width,.18,1.6))
		for x in [-width*.5+ .1,0]:
			for z in [.4,8.2,17.7]:
				var top := minf(rear_height,1+z/.82*.38)
				var bottom := -.2-outside.y
				_box("SupportSteel",pose,Vector3(x,(top+bottom)*.5,z),Vector3(.18,top-bottom,.18))
			_beam(pose,Vector3(x,1,.3),Vector3(x,rear_height,16.4),.15)
			_beam(pose,Vector3(x,0,.4),Vector3(x,rear_height,17.7),.10)
			_beam(pose,Vector3(x,0,17.7),Vector3(x,rear_height*.5,8.2),.10)
			_beam(pose,Vector3(x,rear_height,17.9),Vector3(x,rear_height+1.1,17.9),.05)
		for h in [.55,1.1]:
			_beam(pose,Vector3(-width*.5,rear_height+h,17.9),Vector3(width*.5,rear_height+h,17.9),.045)
		# Stair handrail follows the rake without blocking the seating bays.
		var aisle_x := -width*.5+.12
		_beam(pose,Vector3(aisle_x,2,.1),Vector3(aisle_x,rear_height+1,16.4),.045)
		for row in range(0,ROWS,4):
			var h := 1+row*.38
			_beam(pose,Vector3(aisle_x,h,row*.82),Vector3(aisle_x,h+1,row*.82),.045)
		if bay in [0,BAYS-1]:
			var x := -width*.5 if bay == 0 else width*.5
			_beam(pose,Vector3(x,2,.1),Vector3(x,rear_height+1,16.4),.045)
	for key in _builders:
		var builder: SurfaceTool = _builders[key]
		var mesh := MeshInstance3D.new()
		mesh.name = key
		mesh.mesh = builder.commit()
		add_child(mesh)
	_builders.clear()

func _v(p: Array) -> Vector3:
	return Vector3(p[0],p[1],p[2])

func _box(key: String,pose: Transform3D,position: Vector3,size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,box.surface_get_arrays(0))
	var builder: SurfaceTool = _builders[key]
	builder.append_from(mesh,0,pose*Transform3D(Basis.IDENTITY,position))

func _beam(pose: Transform3D,a: Vector3,b: Vector3,width: float) -> void:
	var axis := (b-a).normalized()
	var side := axis.cross(Vector3.FORWARD).normalized()
	if side.length_squared() < .5: side = axis.cross(Vector3.RIGHT).normalized()
	var beam_pose := pose*Transform3D(Basis(side,axis,side.cross(axis)),(a+b)*.5)
	_box("SupportSteel",beam_pose,Vector3.ZERO,Vector3(width,a.distance_to(b),width))
