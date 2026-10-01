@tool
extends Node3D
## Static broadcast towers; local +Z faces the racing surface.
const DECK := 5.7
# End towers sit inside the inner wall; the middle one clears the RV row and roads.
const SITES := [Vector3(-145, 0, -81), Vector3(-15, 0, -46), Vector3(145, 0, -81)]
var steel: StandardMaterial3D
var dark: StandardMaterial3D
var deck_mat: StandardMaterial3D
var skin: StandardMaterial3D
var shirt: StandardMaterial3D
var lens: StandardMaterial3D

func _ready() -> void:
	steel = _material("89979b")
	dark = _material("242c33")
	deck_mat = _material("515f65")
	skin = _material("bf9373")
	shirt = _material("59788b")
	lens = _material("294955")
	for i in range(3):
		var tower := Node3D.new()
		tower.name = "TVPlatform%d" % (i + 1)
		tower.position = SITES[i]
		tower.rotation.y = PI
		add_child(tower)
		_build_tower(tower, i)

func _build_tower(t: Node3D, index: int) -> void:
	_box(t, "Deck", Vector3(0, DECK - .12, 0), Vector3(3.2, .24, 3.0), deck_mat)
	for x in [-1.4, 1.4]:
		for z in [-1.3, 1.3]:
			_box(t, "Footing", Vector3(x, .12, z), Vector3(.65, .24, .65), deck_mat)
			_beam(t, "ScaffoldPost", Vector3(x, .24, z), Vector3(x, DECK + 1.1, z), .055, steel)
		for y in [0.35, 2.95]:
			_beam(t, "SideBrace", Vector3(x, y, -1.3), Vector3(x, y + 2.6, 1.3), .035, steel)
			_beam(t, "SideBrace", Vector3(x, y, 1.3), Vector3(x, y + 2.6, -1.3), .035, steel)
		for h in [.55, 1.1]:
			_beam(t, "SideRail", Vector3(x, DECK + h, -1.3), Vector3(x, DECK + h, 1.3), .035, steel)
	for z in [-1.3, 1.3]:
		_beam(t, "CrossBrace", Vector3(-1.4, .35, z), Vector3(1.4, DECK - .2, z), .035, steel)
		_beam(t, "CrossBrace", Vector3(1.4, .35, z), Vector3(-1.4, DECK - .2, z), .035, steel)
		for h in [.55, 1.1]:
			# Leave a rear corner opening for the access ladder.
			_beam(t, "GuardRail", Vector3(-1.4, DECK + h, z), Vector3(.55 if z < 0 else 1.4, DECK + h, z), .035, steel)
		_box(t, "ToeBoard", Vector3(0, DECK + .09, z), Vector3(2.8, .18, .06), deck_mat)
	for x in [.65, 1.3]:
		_beam(t, "LadderRail", Vector3(x, .1, -1.95), Vector3(x, DECK + .9, -1.4), .035, steel)
	for i in range(19):
		var y := .25 + i * .3
		var z := -1.95 + (y - .1) / (DECK + .8) * .55
		_beam(t, "LadderRung", Vector3(.65, y, z), Vector3(1.3, y, z), .025, steel)
	_box(t, "BroadcastFascia", Vector3(0, DECK - .36, 1.51), Vector3(3.2, .48, .06), dark)
	var label := Label3D.new()
	label.name = "CameraNumber"
	label.text = "TV  /  %02d" % (index + 1)
	label.font_size = 64
	label.pixel_size = .0045
	label.position = Vector3(0, DECK - .36, 1.55)
	label.modulate = Color("e6e5d8")
	t.add_child(label)
	var rig := Node3D.new()
	rig.name = "CameraAndOperator"
	rig.position.y = DECK
	rig.rotation.y = [.18, 0.0, -.18][index]
	t.add_child(rig)
	# Heavy broadcast camera, long lens hood, viewfinder and pan handles.
	for foot in [Vector3(-.52, 0, .85), Vector3(.52, 0, .85), Vector3(0, 0, -.12)]:
		_beam(rig, "TripodLeg", foot, Vector3(0, 1.18, .45), .045, dark)
	_box(rig, "PanHead", Vector3(0, 1.22, .45), Vector3(.28, .16, .3), steel)
	_box(rig, "CameraBody", Vector3(0, 1.48, .51), Vector3(.48, .42, .72), deck_mat)
	_box(rig, "LensHood", Vector3(0, 1.48, 1.01), Vector3(.43, .34, .32), dark)
	_box(rig, "LensGlass", Vector3(0, 1.48, 1.177), Vector3(.32, .23, .015), lens)
	_box(rig, "Battery", Vector3(0, 1.48, .08), Vector3(.36, .32, .16), dark)
	_box(rig, "Viewfinder", Vector3(-.25, 1.69, .12), Vector3(.18, .13, .3), dark)
	_beam(rig, "CarryHandle", Vector3(-.12, 1.77, .3), Vector3(-.12, 1.77, .65), .025, dark)
	for x in [-.27, .27]:
		_beam(rig, "PanHandle", Vector3(x, 1.25, .32), Vector3(x, 1.05, -.32), .023, dark)
	# Operator leans into the viewfinder, with both hands on the pan handles.
	for x in [-.18, .18]:
		_box(rig, "Boot", Vector3(x, .08, -.62), Vector3(.2, .16, .34), dark)
		_beam(rig, "TrouserLeg", Vector3(x, .17, -.7), Vector3(x * .8, .88, -.61), .095, dark)
	_box(rig, "OperatorTorso", Vector3(0, 1.15, -.55), Vector3(.48, .58, .3), shirt).rotation.x = .14
	_box(rig, "Neck", Vector3(0, 1.49, -.47), Vector3(.13, .16, .13), skin)
	_box(rig, "Head", Vector3(0, 1.68, -.43), Vector3(.25, .3, .25), skin)
	_box(rig, "Cap", Vector3(0, 1.85, -.43), Vector3(.28, .08, .28), dark)
	_box(rig, "CapBrim", Vector3(0, 1.82, -.25), Vector3(.28, .035, .18), dark)
	for x in [-.15, .15]:
		_box(rig, "Headset", Vector3(x, 1.7, -.43), Vector3(.07, .15, .12), dark)
	for side in [-1.0, 1.0]:
		_beam(rig, "Sleeve", Vector3(side * .24, 1.36, -.5), Vector3(side * .34, 1.12, -.54), .085, shirt)
		_beam(rig, "Forearm", Vector3(side * .34, 1.12, -.54), Vector3(side * .27, 1.05, -.3), .06, skin)
	_box(t, "EquipmentCase", Vector3(-.96, DECK + .2, -.7), Vector3(.5, .4, .65), dark)

func _material(hex: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = .8
	return mat

func _box(parent: Node3D, label: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node

func _beam(parent: Node3D, label: String, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var node := _box(parent, label, (a + b) * .5, Vector3(radius * 2, a.distance_to(b), radius * 2), mat)
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.FORWARD).normalized()
	if side.length_squared() < .5:
		side = axis.cross(Vector3.RIGHT).normalized()
	node.basis = Basis(side, axis, side.cross(axis))


