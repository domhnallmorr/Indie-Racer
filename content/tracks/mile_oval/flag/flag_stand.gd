@tool
extends Node3D
## Raised starter's platform, aligned with the middle of the finish stripe.
const FINISH_X := ((1609.344-TAU*125.0)/2.0)*.15+.7
const DECK := 5.65
var steel: StandardMaterial3D
var white: StandardMaterial3D
var dark: StandardMaterial3D

func _ready() -> void:
	position = Vector3(FINISH_X,0,136.0)
	steel = _material(Color("8d999e"))
	white = _material(Color("dcded9"))
	dark = _material(Color("293b46"))
	# The deck clears the existing 5.15 m catchfence, with a trackward overhang.
	_box("Deck",Vector3(0,DECK,0),Vector3(4.8,.22,4.2),dark)
	_box("Roof",Vector3(0,8.05,0),Vector3(5.25,.17,4.65),white)
	for x in [-2.1,2.1]:
		for z in [.1,1.8]:
			_box("ConcreteFoot",Vector3(x,.15,z),Vector3(.8,.3,.8),white)
			_beam("Support",Vector3(x,.3,z),Vector3(x,DECK,z),.15,steel)
		_beam("CrossBrace",Vector3(x,.4,.1),Vector3(x,DECK,1.8),.09,steel)
		_beam("Cantilever",Vector3(x,3.5,.1),Vector3(x,DECK,-2.0),.11,steel)
		for z in [-1.9,1.9]:
			_beam("RoofPost",Vector3(x,DECK,z),Vector3(x,8.0,z),.075,steel)
		for h in [.55,1.1]:
			_beam("SideRail",Vector3(x,DECK+h,-1.9),Vector3(x,DECK+h,1.9),.05,steel)
		for z in [-.9,.1,1.0]:
			_beam("SideUpright",Vector3(x,DECK,z),Vector3(x,DECK+1.1,z),.035,steel)
	for h in [.55,1.1]:
		_beam("FrontRail",Vector3(-2.1,DECK+h,-1.9),Vector3(2.1,DECK+h,-1.9),.05,steel)
		_beam("RearRail",Vector3(-2.1,DECK+h,1.9),Vector3(.65,DECK+h,1.9),.05,steel)
	for x in [-1.05,0,1.05]:
		_beam("FrontUpright",Vector3(x,DECK,-1.9),Vector3(x,DECK+1.1,-1.9),.035,steel)
	# Narrow rear access stair, rising away from the spectator seating.
	for i in range(24):
		var y := (i+1)*DECK/24.0
		var z := 9.6-i*.32
		_box("StairTread",Vector3(1.35,y,z),Vector3(1.15,.10,.34),steel)
	for x in [.72,1.98]:
		_beam("StairStringer",Vector3(x,.1,9.85),Vector3(x,DECK,2.0),.09,dark)
		_beam("StairHandrail",Vector3(x,1.1,9.85),Vector3(x,DECK+1.0,2.0),.045,steel)
		for i in range(0,24,4):
			var y := (i+1)*DECK/24.0
			var z := 9.6-i*.32
			_beam("StairRailPost",Vector3(x,y,z),Vector3(x,y+1.0,z),.035,steel)
	_box("FrontFascia",Vector3(0,DECK-.29,-2.13),Vector3(4.8,.65,.10),dark)
	for x in range(12):
		for y in range(2):
			_box("Checker",Vector3(-2.2+x*.4,DECK-.13-y*.3,-2.19),Vector3(.395,.295,.015),white if (x+y)%2 == 0 else dark)
	# Stowed flags identify the function without displaying a live race signal.
	var green := _material(Color("269547"))
	var yellow := _material(Color("ead02a"))
	for i in range(3):
		var x := -1.5+i*.5
		_beam("FlagHandle",Vector3(x,DECK+.1,1.65),Vector3(x,DECK+1.9,1.65),.022,steel)
		_box("StowedFlag",Vector3(x+.09,DECK+1.37,1.65),Vector3(.18,.75,.06),[green,yellow,white][i])
		if i == 2:
			for j in range(4):
				_box("FoldedChecks",Vector3(x+.09,DECK+1.1+j*.18,1.611),Vector3(.17,.09,.02),dark)
	_box("FlagRack",Vector3(-1.0,DECK+.3,1.65),Vector3(1.6,.18,.32),dark)

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = .75
	return mat

func _box(label: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.material_override = mat
	node.position = pos
	add_child(node)
	return node

func _beam(label: String, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var beam := _box(label,(a+b)*.5,Vector3(radius*2,a.distance_to(b),radius*2),mat)
	var axis := (b-a).normalized()
	var side := axis.cross(Vector3.FORWARD).normalized()
	if side.length_squared() < .5:
		side = axis.cross(Vector3.RIGHT).normalized()
	beam.basis = Basis(side,axis,side.cross(axis))
