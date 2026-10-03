@tool
extends Node3D
## Track-facing advertising, outside the fence and before the Turn 4 grandstand.
const LAP := 2414.016
const BOARDS := [
	[620.0,"FIRESTONE","b2262e","ffffff"],
	[670.0,"PENNZOIL","e3bb35","252b30"],
	[720.0,"DELPHI","f0eee3","b6282c"],
	[1900.0,"ACDelco","214d87","ffffff"],
	[1950.0,"SUNOCO","e7bc26","24477b"],
	[2000.0,"TARGET","b82730","ffffff"]
]
var _builders: Dictionary = {}
var board_poses: Array[Transform3D] = []
func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/texas/geometry.json"))
	var road: Array = []
	for strip in data.strips:
		if strip.name == "RacingSurface": road = strip.rows
	_material("Steel","687477")
	_material("Backs","434d50")
	_material("Footings","a4a599")
	_material("Frame","d2d5cc")
	for index in range(BOARDS.size()):
		var board: Array = BOARDS[index]
		_material(str(index),board[2])
		var at: float = float(board[0])/LAP*(road.size()-1)
		var i := int(at)
		var outer := _v(road[i][0]).lerp(_v(road[i+1][0]),at-i)
		var inner := _v(road[i][-1]).lerp(_v(road[i+1][-1]),at-i)
		var outward := outer-inner
		outward.y = 0
		outward = outward.normalized()
		var center := outer+outward*11.0+Vector3.UP*10.0
		var pose := Transform3D(Basis(Vector3.UP.cross(outward),Vector3.UP,outward),center)
		board_poses.append(pose)
		_box("Backs",pose,Vector3.ZERO,Vector3(34,7.5,.5))
		_box(str(index),pose,Vector3(0,0,-.28),Vector3(33.6,7.1,.10))
		for y in [-3.7,3.7]:
			_box("Frame",pose,Vector3(0,y,-.37),Vector3(34,.16,.13))
		for x in [-16.9,16.9]:
			_box("Frame",pose,Vector3(x,0,-.37),Vector3(.16,7.5,.13))
		for x in [-12.0,0.0,12.0]:
			var height := center.y+3.5+.2
			_box("Steel",pose,Vector3(x,3.5-height*.5,.55),Vector3(.32,height,.38))
			_box("Footings",pose,Vector3(x,-center.y+.15,.55),Vector3(1.2,.7,1.2))
		for y in [-2.5,2.5]:
			_box("Steel",pose,Vector3(0,y,.62),Vector3(33,.2,.24))
		var label := Label3D.new()
		label.name = "Advert%d" % index
		label.text = board[1]
		label.font_size = 128
		label.pixel_size = .041
		label.outline_size = 0
		label.modulate = Color(board[3])
		label.transform = pose*Transform3D(Basis(Vector3.UP,PI),Vector3(0,.15,-.41))
		add_child(label)
	for key in _builders:
		var mesh := MeshInstance3D.new()
		mesh.name = "BoardMaterial"+key
		mesh.mesh = _builders[key].commit()
		add_child(mesh)
	_builders.clear()
func _material(key: String,color: String) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = .85
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(material)
	_builders[key] = builder
func _box(key: String,pose: Transform3D,p: Vector3,size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,box.surface_get_arrays(0))
	_builders[key].append_from(mesh,0,pose*Transform3D(Basis.IDENTITY,p))
func _v(p: Array) -> Vector3:
	return Vector3(p[0],p[1],p[2])
