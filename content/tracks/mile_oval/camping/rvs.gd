@tool
extends Node3D
## Five shared meshes, thirty campsites. Coordinates are track-local metres.
const MODEL_NAMES := ["Motorcoach", "CabOver", "SilverTrailer", "FifthWheel", "CamperVan"]
const HALF_STRAIGHT := (1609.344 - TAU * 125.0) / 4.0
const RUBBER := Color("25282a")
const GLASS := Color("263f4b")
const TRIM := Color("a5adb0")
var placements: Array[Transform3D] = []
var model_meshes: Array[ArrayMesh] = []

func _ready() -> void:
	var groups: Array = [[], [], [], [], []]
	var rng := RandomNumberGenerator.new()
	rng.seed = 19870524
	for cluster in range(3):
		for row in range(2):
			for slot in range(5):
				var point: Vector3
				var yaw: float
				if cluster == 1:
					point = Vector3(-73.0 + (slot + row * 5) * 13.3, 0, -77.0)
					yaw = PI / 2.0
				else:
					var angle := deg_to_rad(9.0 + (slot + row * 5) * 8.8)
					var radius := 74.0
					var side := 1.0 if cluster == 0 else -1.0
					point = Vector3(side * (HALF_STRAIGHT + cos(angle) * radius), 0, -sin(angle) * radius)
					yaw = side * angle
				point += Vector3(rng.randf_range(-0.6,0.6),0,rng.randf_range(-0.6,0.6))
				var pose := Transform3D(Basis(Vector3.UP,yaw + rng.randf_range(-0.10,0.10)),point)
				groups[(slot + row * 2 + cluster) % 5].append(pose)
				placements.append(pose)
	for variant in range(5):
		var mesh := make_rv(variant)
		model_meshes.append(mesh)
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = groups[variant].size()
		for i in range(multi.instance_count):
			multi.set_instance_transform(i,groups[variant][i])
		var batch := MultiMeshInstance3D.new()
		batch.name = MODEL_NAMES[variant]
		batch.multimesh = multi
		add_child(batch)

func make_rv(variant: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.72
	surface.set_material(material)
	var length: float = [10.8,8.0,7.6,9.4,5.7][variant]
	var height: float = [3.5,3.15,2.9,3.6,2.65][variant]
	var width := 2.5 if variant != 4 else 2.1
	var body: Color = [Color("e9e2cd"),Color("eeeade"),Color("b9c1c3"),Color("d3c4a8"),Color("dee0ca")][variant]
	var accent: Color = [Color("783c36"),Color("466a8b"),Color("647c86"),Color("675644"),Color("5b7463")][variant]
	var front := -length * 0.5
	var rear := length * 0.5
	_box(surface,Vector3(0,0.65,0),Vector3(width-0.2,0.24,length-0.2),RUBBER)
	if variant == 2:
		# Rounded aluminum trailer: extruded twelve-sided shell, flat floor.
		var profile := PackedVector2Array([Vector2(-1.25,0.8),Vector2(1.25,0.8),Vector2(1.25,2.15),Vector2(1.16,2.52),Vector2(0.87,2.82),Vector2(0.45,2.98),Vector2(-0.45,2.98),Vector2(-0.87,2.82),Vector2(-1.16,2.52),Vector2(-1.25,2.15)])
		_shell(surface,profile,length,body)
		for z in [-2.7,-1.2,0.3,1.8,3.2]:
			for x in [-1.256,1.256]:
				_box(surface,Vector3(x,1.55,z),Vector3(0.016,1.45,0.035),TRIM)
	elif variant == 1 or variant == 4:
		_box(surface,Vector3(0,(height+0.8)/2,0.7),Vector3(width,height-0.8,length-1.4),body)
		_box(surface,Vector3(0,1.35,front+0.75),Vector3(width-0.22,1.4,1.5),body)
		_box(surface,Vector3(0,2.05,front+0.83),Vector3(width-0.3,0.9,1.1),body)
		if variant == 1:
			_box(surface,Vector3(0,2.96,front+0.9),Vector3(width,0.8,2.2),body)
	else:
		_box(surface,Vector3(0,(height+0.8)/2,0),Vector3(width,height-0.8,length),body)
		if variant == 3:
			# Raised overhanging bedroom above the fifth-wheel hitch.
			_box(surface,Vector3(0,2.9,front-0.65),Vector3(width,1.4,1.3),body)
			_box(surface,Vector3(0,1.98,front-0.6),Vector3(0.22,0.55,0.22),RUBBER)
	for side in [-1.0,1.0]:
		_box(surface,Vector3(side*(width/2+0.013),1.27,0.35),Vector3(0.035,0.29,length-1.6),accent)
		_box(surface,Vector3(side*(width/2+0.018),1.04,0.35),Vector3(0.038,0.06,length-1.6),TRIM)
		for z in [-length*0.23,0.15,length*0.29]:
			_box(surface,Vector3(side*(width/2+0.025),2.25,z),Vector3(0.045,0.82,1.12),RUBBER)
			_box(surface,Vector3(side*(width/2+0.05),2.25,z),Vector3(0.02,0.66,0.95),GLASS)
			_box(surface,Vector3(side*(width/2+0.065),2.25,z),Vector3(0.02,0.67,0.035),TRIM)
		var axles := [-length*0.31,length*0.30] if variant != 2 and variant != 3 else [0.7,1.8]
		if variant == 0:
			axles.append(length*0.30-1.05)
		for z in axles:
			_wheel(surface,Vector3(side*(width/2-0.02),0.48,z),0.48,0.25,RUBBER)
			_wheel(surface,Vector3(side*(width/2+0.12),0.48,z),0.25,0.025,TRIM)
	if variant in [0,1,4]:
		var windshield_y := 2.65 if variant == 0 else 2.12
		var windshield_z := front-0.016 if variant == 0 else front+0.263
		_box(surface,Vector3(0,windshield_y,windshield_z),Vector3(width-0.38,0.84,0.035),GLASS)
		_box(surface,Vector3(0,windshield_y,windshield_z-0.025),Vector3(0.055,0.84,0.02),TRIM)
		_box(surface,Vector3(0,1.0,front-0.035),Vector3(0.95,0.28,0.06),RUBBER)
		for x in [-0.78,0.78]:
			_box(surface,Vector3(x,1.13,front-0.06),Vector3(0.33,0.17,0.07),Color("efe7bc"))
			_box(surface,Vector3(x*1.8,2.0,front+0.55),Vector3(0.18,0.34,0.24),RUBBER)
	else:
		_box(surface,Vector3(0,0.58,front-0.65),Vector3(0.14,0.16,1.5),TRIM)
		_box(surface,Vector3(0,0.33,front-1.1),Vector3(0.12,0.6,0.12),TRIM)
	for x in [-width*0.37,width*0.37]:
		_box(surface,Vector3(x,1.22,rear+0.025),Vector3(0.18,0.3,0.04),Color("9b342c"))
	_box(surface,Vector3(0,0.79,rear+0.06),Vector3(width,0.17,0.14),TRIM)
	# Entry door, roof air conditioning, vents, and a rear access ladder.
	_box(surface,Vector3(width/2+0.065,1.69,-length*0.29),Vector3(0.04,1.85,0.73),accent)
	_box(surface,Vector3(width/2+0.09,2.12,-length*0.29),Vector3(0.03,0.65,0.5),GLASS)
	_box(surface,Vector3(width/2+0.3,0.42,-length*0.29),Vector3(0.6,0.16,0.85),TRIM)
	_box(surface,Vector3(0,height+0.18,0.35),Vector3(0.88,0.34,1.1),Color("deddd4"))
	_box(surface,Vector3(0.35,height+0.05,2.0),Vector3(0.48,0.1,0.48),TRIM)
	for x in [0.65,1.02]:
		_box(surface,Vector3(x,2.0,rear+0.12),Vector3(0.045,2.55,0.045),TRIM)
	for step in range(8):
		_box(surface,Vector3(0.835,0.86+step*0.31,rear+0.12),Vector3(0.41,0.035,0.045),TRIM)
	if variant != 4:
		# Striped awning and simple folding seats give each parking spot a campsite.
		for stripe in range(10):
			_box(surface,Vector3(width/2+1.05,2.8,-1.5+stripe*0.38),Vector3(2.1,0.07,0.38),accent if stripe%2==0 else body)
		for z in [-1.5,2.0]:
			_box(surface,Vector3(width/2+2.05,1.4,z),Vector3(0.045,2.8,0.045),TRIM)
		for z in [-0.7,1.2]:
			_box(surface,Vector3(2.65,0.48,z),Vector3(0.52,0.08,0.52),accent)
			_box(surface,Vector3(2.88,0.8,z),Vector3(0.07,0.58,0.52),accent)
			for x in [2.43,2.86]:
				_box(surface,Vector3(x,0.24,z),Vector3(0.04,0.48,0.45),TRIM)
		_box(surface,Vector3(2.6,0.25,0.28),Vector3(0.6,0.5,0.4),Color("af4b3d"))
		_box(surface,Vector3(2.6,0.52,0.28),Vector3(0.63,0.06,0.43),Color("e6e2d6"))
	surface.index()
	return surface.commit()

func _box(surface: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = size
	_primitive(surface,box,Transform3D(Basis.IDENTITY,center),color)

func _wheel(surface: SurfaceTool, center: Vector3, radius: float, width: float, color: Color) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = width
	cylinder.radial_segments = 12
	_primitive(surface,cylinder,Transform3D(Basis(Vector3.FORWARD,PI/2),center),color)

func _primitive(surface: SurfaceTool, mesh: PrimitiveMesh, pose: Transform3D, color: Color) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		surface.set_color(color.srgb_to_linear())
		surface.set_normal(pose.basis * normals[index])
		surface.add_vertex(pose * vertices[index])

func _shell(surface: SurfaceTool, profile: PackedVector2Array, length: float, color: Color) -> void:
	var polygon := Geometry2D.triangulate_polygon(profile)
	for end in [-1.0,1.0]:
		for i in range(0,polygon.size(),3):
			for j in ([0,1,2] if end < 0 else [2,1,0]):
				var p := profile[polygon[i+j]]
				surface.set_color(color.srgb_to_linear())
				surface.set_normal(Vector3(0,0,end))
				surface.add_vertex(Vector3(p.x,p.y,end*length/2))
	for i in range(profile.size()):
		var a := profile[i]
		var b := profile[(i+1)%profile.size()]
		var normal := Vector3(b.y-a.y,a.x-b.x,0).normalized()
		for p in [Vector3(a.x,a.y,-length/2),Vector3(a.x,a.y,length/2),Vector3(b.x,b.y,-length/2),Vector3(b.x,b.y,-length/2),Vector3(a.x,a.y,length/2),Vector3(b.x,b.y,length/2)]:
			surface.set_color(color.srgb_to_linear())
			surface.set_normal(normal)
			surface.add_vertex(p)

