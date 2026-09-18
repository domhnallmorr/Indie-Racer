@tool
extends Node3D
## Milwaukee-inspired media / care centre. Dimensions in metres.
const LENGTH := 105.6
const WIDTH := 18.0
const EAVE := 3.4
const RIDGE := 4.65
var wall: StandardMaterial3D
var trim: StandardMaterial3D
var glass: StandardMaterial3D
var roof: StandardMaterial3D

func _ready() -> void:
	# Replace both the visible placeholder and its full-size collision.
	for old in get_parent().get_node("Geometry").find_children("PitBuilding*", "MeshInstance3D", true, false):
		old.hide()
		for body in old.find_children("*", "StaticBody3D", true, false):
			body.collision_layer = 0
			body.collision_mask = 0
	position = Vector3(20, 0, 58)
	wall = _material(Color("bdb6a4"))
	trim = _material(Color("dad8cd"))
	glass = _material(Color("304853"), .28)
	roof = _material(Color("454e4d"))
	var foundation := _material(Color("827f72"))
	var frame := _material(Color("565e5a"))
	_box("SingleStorey", Vector3(0,EAVE*.5,0), Vector3(LENGTH,EAVE,WIDTH),wall)
	_box("Foundation",Vector3(0,.18,0),Vector3(LENGTH+.08,.36,WIDTH+.08),foundation)
	_box("Walkway",Vector3(0,.045,0),Vector3(LENGTH+3.6,.08,WIDTH+3.6),trim)
	_make_roof()
	# Long elevations: grouped office windows and two public entrances.
	for side in [-1.0, 1.0]:
		for i in range(18):
			var x := -47.6 + i*5.6
			if absf(x+25.2) < 2.0 or absf(x-25.2) < 2.0:
				_door(x,side,frame)
			else:
				_window(x,side,frame)
		_box("EaveFascia",Vector3(0,EAVE-.08,side*9.42),Vector3(LENGTH+1.4,.24,.16),trim)
		_box("Gutter",Vector3(0,EAVE-.02,side*9.53),Vector3(LENGTH+1.5,.12,.14),roof)
		for x in [-50.5,0.0,50.5]:
			_box("Downpipe",Vector3(x,1.65,side*9.12),Vector3(.11,3.2,.12),trim)
		for x in [-25.2,25.2]:
			_box("EntranceCanopy",Vector3(x,2.85,side*9.7),Vector3(4.6,.14,1.5),roof)
			_box("EntranceSign",Vector3(x,3.12,side*9.13),Vector3(5.1,.38,.12),frame)
			_sign("MEDIA CENTRE" if x < 0 else "MEDICAL CENTRE",Vector3(x,3.12,side*9.205),side)
	# End elevations have service doors, glazing and louvred vents.
	for side in [-1.0,1.0]:
		var end := Node3D.new()
		end.name = "ServiceEnd"
		add_child(end)
		end.position.x = side*LENGTH*.5
		end.rotation.y = side*PI*.5
		_box("ServiceDoor",Vector3(0,1.18,.03),Vector3(1.5,2.3,.1),frame,end)
		_box("DoorPanel",Vector3(0,1.16,.095),Vector3(1.3,2.1,.04),trim,end)
		_box("Handle",Vector3(.45,1.1,.14),Vector3(.06,.3,.06),frame,end)
		for x in [-5.5,5.5]:
			_box("EndWindowFrame",Vector3(x,1.9,.045),Vector3(2.3,1.35,.12),trim,end)
			_box("EndWindow",Vector3(x,1.9,.115),Vector3(2.1,1.15,.04),glass,end)
			_box("EndMullion",Vector3(x,1.9,.15),Vector3(.06,1.18,.05),frame,end)
		for y in range(5):
			_box("VentLouvre",Vector3(0,2.7+y*.09,.10),Vector3(1.2,.045,.10),roof,end)
		_box("EndFascia",Vector3(side*(LENGTH*.5+.62),EAVE-.08,0),Vector3(.16,.24,18.85),trim)
	var body := StaticBody3D.new()
	body.name = "BuildingCollision"
	add_child(body)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(LENGTH,EAVE,WIDTH)
	collider.shape = shape
	collider.position.y = EAVE*.5
	body.add_child(collider)
	# Include the shallow hip roof in collision without retaining the old 8 m box.
	var roof_shape := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = PackedVector3Array([
		Vector3(-53.5,EAVE,-9.5),Vector3(53.5,EAVE,-9.5),
		Vector3(53.5,EAVE,9.5),Vector3(-53.5,EAVE,9.5),
		Vector3(-44,RIDGE,0),Vector3(44,RIDGE,0)])
	roof_shape.shape = hull
	body.add_child(roof_shape)

func _material(color: Color, roughness: float = .88) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _box(label: String, pos: Vector3, size: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node

func _window(x: float, side: float, frame: Material) -> void:
	_box("WindowSurround",Vector3(x,1.95,side*9.04),Vector3(3.25,1.5,.12),trim)
	_box("WindowGlass",Vector3(x,1.95,side*9.115),Vector3(3.03,1.28,.055),glass)
	_box("WindowSill",Vector3(x,1.17,side*9.14),Vector3(3.4,.12,.3),trim)
	for offset in [-.51,.51]:
		_box("WindowMullion",Vector3(x+offset,1.95,side*9.16),Vector3(.065,1.3,.055),frame)
	_box("WindowTransom",Vector3(x,2.22,side*9.16),Vector3(3.08,.055,.055),frame)

func _door(x: float, side: float, frame: Material) -> void:
	_box("EntranceFrame",Vector3(x,1.27,side*9.06),Vector3(2.5,2.5,.15),trim)
	_box("EntranceGlass",Vector3(x,1.28,side*9.15),Vector3(2.26,2.27,.05),glass)
	_box("DoorCentre",Vector3(x,1.28,side*9.19),Vector3(.09,2.28,.06),frame)
	_box("DoorKickplate",Vector3(x,.25,side*9.19),Vector3(2.25,.25,.06),frame)
	for offset in [-.18,.18]:
		_box("DoorPull",Vector3(x+offset,1.1,side*9.25),Vector3(.045,.45,.08),trim)

func _sign(text: String, pos: Vector3, side: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = .005
	label.outline_size = 0
	label.modulate = Color("eee9d6")
	label.position = pos
	label.rotation.y = PI if side < 0 else 0.0
	add_child(label)

func _make_roof() -> void:
	var a := Vector3(-53.5,EAVE,-9.5)
	var b := Vector3(53.5,EAVE,-9.5)
	var c := Vector3(53.5,EAVE,9.5)
	var d := Vector3(-53.5,EAVE,9.5)
	var e := Vector3(-44,RIDGE,0)
	var f := Vector3(44,RIDGE,0)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle in [[a,b,f],[a,f,e],[b,c,f],[c,d,e],[c,e,f],[d,a,e]]:
		var normal: Vector3 = (triangle[2]-triangle[0]).cross(triangle[1]-triangle[0]).normalized()
		for point in triangle:
			surface.set_normal(normal)
			surface.add_vertex(point)
	var mesh := MeshInstance3D.new()
	mesh.name = "ShallowHipRoof"
	mesh.mesh = surface.commit()
	mesh.material_override = roof
	add_child(mesh)
	_box("RidgeCap",Vector3(0,RIDGE+.025,0),Vector3(88.2,.07,.18),roof)
