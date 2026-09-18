@tool
extends Node3D
## One shared transporter mesh; instance custom data supplies sponsor paint.
const LIVERIES := [
	["MARLBORO", "d52a26"], ["TARGET", "c92129"], ["PENNZOIL", "edbf19"],
	["MILLER", "213c75"], ["TEXACO", "292c30"], ["KODAK", "e8ad17"],
	["VALVOLINE", "234e9d"], ["KOOL", "18734b"], ["DURACELL", "9b5b32"],
	["BUDWEISER", "aa222b"], ["GOODYEAR", "263a75"], ["CASTROL", "236442"],
	["MOTOROLA", "254a83"]
]
const TYRE := Color("202124")
const METAL := Color("9ba6aa")
const WHITE := Color("e5e5df")
const GLASS := Color("233d4d")
var placements: Array[Transform3D] = []

func _ready() -> void:
	var mesh := _make_truck()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = mesh
	for row in range(2):
		for slot in range(10):
			placements.append(Transform3D(Basis(Vector3.UP,PI if row == 0 else 0.0),Vector3(-180+slot*11, .06, 32+row*32)))
	for row in range(2):
		for slot in range(3):
			placements.append(Transform3D(Basis(Vector3.UP,PI if row == 0 else 0.0),Vector3(86+slot*13, .06, 32+row*32)))
	multi.instance_count = placements.size()
	for i in range(placements.size()):
		var pose := placements[i]
		var sponsor: Array = LIVERIES[(i*5+i/13) % LIVERIES.size()]
		multi.set_instance_transform(i,pose)
		multi.set_instance_color(i,Color.WHITE)
		multi.set_instance_custom_data(i,Color(sponsor[1]).srgb_to_linear())
		for side in [-1.0,1.0]:
			var label := Label3D.new()
			label.name = "Sponsor_%02d" % i
			label.text = sponsor[0]
			label.font_size = 80
			label.pixel_size = .009
			label.outline_size = 5
			label.outline_modulate = Color("172029")
			label.modulate = Color("faf6e7")
			label.no_depth_test = false
			label.transform = pose * Transform3D(Basis(Vector3.UP,side*PI*.5),Vector3(side*1.315,2.85,3.15))
			add_child(label)
	var batch := MultiMeshInstance3D.new()
	batch.name = "TeamTransporters"
	batch.multimesh = multi
	add_child(batch)

func _make_truck() -> ArrayMesh:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://content/tracks/mile_oval/transporters/paint.gdshader")
	s.set_material(mat)
	# Trailer: 13.6 m enclosed equipment transporter, 2.6 m wide, 4.1 m high.
	_box(s,Vector3(0,2.65,3.2),Vector3(2.6,2.9,13.6),WHITE,true)
	_box(s,Vector3(0,1.12,3.2),Vector3(2.3,.24,13.7),TYRE)
	_box(s,Vector3(0,4.12,3.2),Vector3(2.62,.07,13.65),WHITE)
	for side in [-1.0,1.0]:
		_box(s,Vector3(side*1.31,1.64,3.2),Vector3(.025,.42,13.6),WHITE)
		_box(s,Vector3(side*1.33,1.34,3.2),Vector3(.025,.075,13.6),METAL)
		_box(s,Vector3(side*1.32,3.97,3.2),Vector3(.025,.06,13.6),METAL)
		# Lower storage lockers and amber side markers.
		for z in [-2.5,-.4,1.7,3.8]:
			_box(s,Vector3(side*1.32,1.6,z),Vector3(.03,.31,1.85),METAL)
			_box(s,Vector3(side*1.345,1.7,z),Vector3(.03,.035,.21),TYRE)
		for z in [-3.35,0.0,4.0,9.75]:
			_box(s,Vector3(side*1.345,1.92,z),Vector3(.04,.1,.14),Color("e6a536"))
		_box(s,Vector3(side*.88,.65,-1.9),Vector3(.15,1.1,.15),METAL)
		_box(s,Vector3(side*.88,.14,-1.9),Vector3(.42,.12,.42),TYRE)
	# Rear loading doors, hinges, locking bars, lamps and underride bumper.
	_box(s,Vector3(0,2.63,10.025),Vector3(2.4,2.7,.06),METAL)
	for x in [-.61,.61]:
		_box(s,Vector3(x,2.64,10.07),Vector3(1.15,2.55,.04),WHITE,true)
		_box(s,Vector3(x,2.6,10.12),Vector3(.055,2.3,.055),METAL)
		for y in [1.6,2.6,3.65]:
			_box(s,Vector3(signf(x)*1.17,y,10.12),Vector3(.24,.07,.055),METAL)
	_box(s,Vector3(0,.65,10.05),Vector3(2.45,.18,.22),METAL)
	for x in [-1.02,1.02]:
		_box(s,Vector3(x,1.15,10.12),Vector3(.26,.15,.08),Color("b82b24"))
	# Conventional American tractor: sleeper, glazed cab, long bonnet and grille.
	_box(s,Vector3(0,.9,-6.6),Vector3(2.25,.3,8.7),TYRE)
	_box(s,Vector3(0,2.32,-4.7),Vector3(2.4,2.9,2.0),WHITE,true)
	_box(s,Vector3(0,1.97,-6.75),Vector3(2.35,2.15,2.05),WHITE,true)
	_box(s,Vector3(0,1.46,-9),Vector3(1.6,1.15,2.55),WHITE,true)
	_box(s,Vector3(0,2.52,-7.79),Vector3(2.06,.82,.04),GLASS)
	_box(s,Vector3(0,2.52,-7.825),Vector3(.075,.84,.04),METAL)
	_box(s,Vector3(0,1.5,-10.3),Vector3(1.47,.99,.1),METAL)
	_box(s,Vector3(0,1.5,-10.36),Vector3(1.26,.81,.04),TYRE)
	for x in range(9):
		_box(s,Vector3(-.55+x*.138,1.5,-10.4),Vector3(.035,.79,.025),METAL)
	_box(s,Vector3(0,.75,-10.48),Vector3(2.55,.3,.2),METAL)
	for side in [-1.0,1.0]:
		_box(s,Vector3(side*1.19,2.49,-6.9),Vector3(.035,.75,1.48),GLASS)
		_box(s,Vector3(side*1.2,1.8,-6.4),Vector3(.06,.06,.3),METAL)
		_box(s,Vector3(side*1.27,.68,-6.4),Vector3(.38,.16,1.9),METAL)
		_box(s,Vector3(side*1.13,1.55,-9.95),Vector3(.55,.35,.3),WHITE,true)
		_box(s,Vector3(side*1.13,1.57,-10.12),Vector3(.43,.22,.04),Color("eee5b9"))
		_box(s,Vector3(side*1.38,2.5,-7.4),Vector3(.35,.045,.08),METAL)
		_box(s,Vector3(side*1.53,2.55,-7.4),Vector3(.1,.45,.23),METAL)
		_box(s,Vector3(side*1.21,2.33,-5.5),Vector3(.13,3.1,.13),METAL)
		_box(s,Vector3(side*1.21,3.9,-5.5),Vector3(.15,.07,.15),TYRE)
		_box(s,Vector3(side*1.12,.93,-5.55),Vector3(.4,.55,1.45),METAL)
		for z in [-8.95,-3.65,-2.35,7.7,9.05]:
			_wheel(s,Vector3(side*1.16,.53,z),.53,.32,TYRE)
			_wheel(s,Vector3(side*1.335,.53,z),.29,.045,METAL)
			_wheel(s,Vector3(side*1.37,.53,z),.11,.05,TYRE)
	for x in [-.9,-.45,0.0,.45,.9]:
		_box(s,Vector3(x,3.09,-7.45),Vector3(.12,.09,.18),Color("e6a536"))
	s.index()
	return s.commit()

func _box(s: SurfaceTool, center: Vector3, size: Vector3, color: Color, painted: bool = false) -> void:
	var box := BoxMesh.new()
	box.size = size
	_primitive(s,box,Transform3D(Basis.IDENTITY,center),color,painted)

func _wheel(s: SurfaceTool, center: Vector3, radius: float, width: float, color: Color) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = width
	cylinder.radial_segments = 12
	_primitive(s,cylinder,Transform3D(Basis(Vector3.FORWARD,PI*.5),center),color,false)

func _primitive(s: SurfaceTool, mesh: PrimitiveMesh, pose: Transform3D, color: Color, painted: bool) -> void:
	var arrays := mesh.surface_get_arrays(0)
	for index in arrays[Mesh.ARRAY_INDEX]:
		s.set_color(color.srgb_to_linear())
		s.set_uv(Vector2(1.0 if painted else 0.0,0.0))
		s.set_normal(pose.basis*arrays[Mesh.ARRAY_NORMAL][index])
		s.add_vertex(pose*arrays[Mesh.ARRAY_VERTEX][index])
