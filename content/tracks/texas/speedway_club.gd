@tool
extends Node3D
## Photo-inspired Speedway Club at the Turn 1 end of the frontstretch stand.
const CROWD = preload("res://content/tracks/mile_oval/grandstands/crowd_support_atlas.png")
var _builders: Dictionary = {}
func _ready() -> void:
	var stand = get_parent().get_node("FrontstretchGrandstand")
	var s: float = stand.END+50.0
	var edge: Vector3 = stand._point(s,8,5)
	var outward: Vector3 = (stand._point(s,9,5)-edge).normalized()
	basis = Basis(Vector3.UP.cross(outward),Vector3.UP,outward)
	position = edge
	var foundation := -.25-position.y
	for pair in [["Concrete","b9bab3"],["Frames","c3c9c9"],["Glass","244958"],["BlueGlass","285569"],["RedTrim","884844"],["Dark","303c42"],["Interior","a69774"],["Spectators","ffffff"]]:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(pair[1])
		mat.roughness = .85
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		if "Glass" in pair[0]:
			mat.metallic = .4
			mat.roughness = .22
		if pair[0] == "Spectators":
			mat.albedo_texture = CROWD
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		builder.set_material(mat)
		_builders[pair[0]] = builder
	# Wide upper glass volume, projecting forward over an open terrace.
	_box("Dark",Vector3(0,39,41),Vector3(52,34,24))
	for side in [-1.0,1.0]:
		_box("Concrete",Vector3(side*29,(56+foundation)*.5,45),Vector3(6,56-foundation,23))
		_box("Frames",Vector3(side*25,17,30),Vector3(.55,14,.55))
	for col in range(15):
		var x := -24.3+col*3.47
		for floor_index in range(9):
			var y := 23.8+floor_index*3.65
			var key := "BlueGlass" if (col+floor_index*3)%7<2 else "Glass"
			_box(key,Vector3(x,y,28.94),Vector3(3.32,3.45,.12))
		_box("Frames",Vector3(x-1.72,39.4,28.8),Vector3(.12,34.8,.22))
	for floor_index in range(10):
		_box("Frames",Vector3(0,22+floor_index*3.65,28.78),Vector3(52,.12,.22))
		if floor_index%3 == 0:
			_box("RedTrim",Vector3(0,22+floor_index*3.65,28.64),Vector3(52,.18,.15))
	# Return glazing on the projecting side walls.
	for side in [-1.0,1.0]:
		_box("Glass",Vector3(side*26.08,39,40),Vector3(.1,34,22))
		for z in range(30,53,3):
			_box("Frames",Vector3(side*26.16,39,z),Vector3(.15,34,.12))
		for y in range(22,57,4):
			_box("Frames",Vector3(side*26.16,y,40),Vector3(.15,.12,22))
	_box("Frames",Vector3(0,56.8,41),Vector3(53,.6,25))
	_box("Concrete",Vector3(0,11.7,32),Vector3(57,.6,23))
	_box("Frames",Vector3(0,21.7,39),Vector3(53,.4,23))
	_box("Interior",Vector3(0,16.7,41),Vector3(51,6,1))
	for x in range(-24,25,8):
		_box("Frames",Vector3(x,17.7,30),Vector3(.45,8.6,.45))
	_box("RedTrim",Vector3(0,14.0,28),Vector3(52,.16,.15))
	# Concrete service core and a taller, stepped blue-glass stair tower.
	_box("Concrete",Vector3(34,(57+foundation)*.5,43),Vector3(13,57-foundation,24))
	for section in range(3):
		var x := 42.0+section*3.0
		var height := 59.0+section*2.0
		_box("BlueGlass",Vector3(x,(height+foundation)*.5,36+section*2),Vector3(3,height-foundation,18))
		for y in range(0,int(height),4):
			_box("RedTrim",Vector3(x,y,26.9+section*2),Vector3(3.1,.14,.16))
		for dx in [-1.45,0.0,1.45]:
			_box("Frames",Vector3(x+dx,(height+foundation)*.5,26.8+section*2),Vector3(.07,height-foundation,.1))
	# Compact terraced seating at the building's foot, with four stair aisles.
	for row in range(22):
		var z := row*.95
		var y := row*.52
		_box("Concrete",Vector3(0,y-.3,z),Vector3(58,.6,1))
		for bay in range(4):
			var x := -28.0+bay*14.5
			_quad("Spectators",Vector3(x,y+.05,z+.1),Vector3(x,y+.55,z+.85),Vector3(x+12.7,y+.55,z+.85),Vector3(x+12.7,y+.05,z+.1),true)
		for side in [-1.0,1.0]:
			_box("Concrete",Vector3(side*29,(y+foundation)*.5,z),Vector3(.35,y-foundation,1))
	_box("Concrete",Vector3(0,foundation*.5,-.55),Vector3(58,-foundation,.35))
	for x in range(-29,30,3):
		_box("Frames",Vector3(x,.6,-.8),Vector3(.08,1.2,.08))
	_box("Frames",Vector3(0,1.2,-.8),Vector3(58,.08,.08))
	# Bridge endpoint comes from the actual suite block, avoiding a floating join.
	var bridge_end: Vector3 = to_local(stand.to_global(stand._point(stand.END,66,40)))
	var bridge_start := Vector3(-29,39,44)
	_bridge(bridge_start,bridge_end)
	for key in _builders:
		var mesh := MeshInstance3D.new()
		mesh.name = key
		mesh.mesh = _builders[key].commit()
		add_child(mesh)
	_builders.clear()
	var sign := Label3D.new()
	sign.name = "ClubSign"
	sign.text = "THE SPEEDWAY CLUB"
	sign.font_size = 110
	sign.pixel_size = .035
	sign.outline_size = 0
	sign.modulate = Color("efefea")
	sign.position = Vector3(0,53.8,28.45)
	sign.rotation.y = PI
	add_child(sign)

func _bridge(a: Vector3,b: Vector3) -> void:
	var direction := (b-a).normalized()
	var frame := Basis(direction,Vector3.UP,direction.cross(Vector3.UP)).orthonormalized()
	var length := a.distance_to(b)
	for pair in [["Concrete",Vector3(0,-2,0),Vector3(length,.5,6)],["Concrete",Vector3(0,2,0),Vector3(length,.5,6)],["Glass",Vector3(0,0,-2.9),Vector3(length,3.6,.12)],["Glass",Vector3(0,0,2.9),Vector3(length,3.6,.12)]]:
		_oriented_box(pair[0],Transform3D(frame,(a+b)*.5+frame*pair[1]),pair[2])
	for i in range(int(length/2)+1):
		for side in [-1.0,1.0]:
			_oriented_box("Frames",Transform3D(frame,(a+b)*.5+frame*Vector3(-length*.5+i*2,0,side*3)),Vector3(.1,4,.15))

func _box(key: String,p: Vector3,size: Vector3) -> void:
	_oriented_box(key,Transform3D(Basis.IDENTITY,p),size)
func _oriented_box(key: String,pose: Transform3D,size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,box.surface_get_arrays(0))
	_builders[key].append_from(mesh,0,pose)
func _quad(key: String,a: Vector3,b: Vector3,c: Vector3,d: Vector3,crowd: bool=false) -> void:
	var verts := [a,b,c,d]
	var uv := [Vector2(0,.065),Vector2(0,.002),Vector2(1,.002),Vector2(1,.065)]
	var builder: SurfaceTool = _builders[key]
	for i in [0,1,2,0,2,3]:
		builder.set_normal((b-a).cross(c-a).normalized())
		builder.set_uv(uv[i] if crowd else Vector2.ZERO)
		builder.add_vertex(verts[i])
