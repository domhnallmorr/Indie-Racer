extends Node3D
## Simple period four-door saloon, facing local -Z; dimensions in metres.
var beacons: Array[MeshInstance3D] = []
var flashing := false
var clock := 0.0

func _ready() -> void:
	var silver := material("b7c2ca", .38, .55)
	var glass := material("233b49", .2, .35)
	var black := material("171b20", .8)
	var chrome := material("c3c8ca", .25, .8)
	loft("Body", [[.32,.79,-2.20,2.20],[.52,.92,-2.35,2.35],[.91,.91,-2.30,2.30],[1.04,.83,-2.17,2.16]], silver)
	box("Bonnet",Vector3(0,1.03,-1.53),Vector3(1.77,.12,1.45),silver)
	box("Boot",Vector3(0,1.02,1.8),Vector3(1.77,.13,.95),silver)
	loft("Cabin", [[1.04,.82,-1.18,1.39],[1.59,.70,-.68,.94]], glass)
	box("Roof",Vector3(0,1.61,.13),Vector3(1.43,.065,1.67),silver)
	for side in [-1.0,1.0]:
		for ends in [[-1.05,-.68],[.12,.12],[1.25,.94]]:
			var bottom := Vector3(side*.82,1.04,ends[0])
			var top := Vector3(side*.70,1.60,ends[1])
			var pillar := box("Pillar",(bottom+top)*.5,Vector3(.05,.055,bottom.distance_to(top)),silver)
			pillar.basis = Basis.looking_at((top-bottom).normalized(),Vector3.FORWARD)
		for z in [-.45,.68]:
			box("DoorHandle",Vector3(side*.92,.95,z),Vector3(.035,.045,.18),chrome)
			box("DoorSeam",Vector3(side*.913,.70,z+.44),Vector3(.012,.46,.013),black)
		box("Mirror",Vector3(side*.99,1.1,-.87),Vector3(.23,.14,.26),silver)
		box("SideStripe",Vector3(side*.916,.73,0),Vector3(.015,.12,3.65),material("204c79"))
		var label := Label3D.new()
		label.text = "PACE CAR"
		label.font_size = 48
		label.pixel_size = .006
		label.position = Vector3(side*.932,.85,0)
		label.rotation.y = side*PI/2
		add_child(label)
		for z in [-1.43,1.46]:
			var wheel := MeshInstance3D.new()
			var tyre := CylinderMesh.new()
			tyre.top_radius = .34
			tyre.bottom_radius = .34
			tyre.height = .22
			tyre.radial_segments = 16
			wheel.mesh = tyre
			wheel.material_override = black
			wheel.rotation.z = PI/2
			wheel.position = Vector3(side*.87,.34,z)
			add_child(wheel)
			var hub := MeshInstance3D.new()
			var rim := CylinderMesh.new()
			rim.top_radius = .22
			rim.bottom_radius = .22
			rim.height = .025
			rim.radial_segments = 12
			hub.mesh = rim
			hub.material_override = chrome
			hub.rotation.z = PI/2
			hub.position = Vector3(side*.99,.34,z)
			add_child(hub)
		box("Headlamp",Vector3(side*.61,.88,-2.335),Vector3(.48,.22,.035),material("fff0c4"))
		box("TailLamp",Vector3(side*.65,.86,2.335),Vector3(.41,.23,.035),material("a51818"))
	box("Grille",Vector3(0,.77,-2.337),Vector3(.61,.22,.04),black)
	for z in [-2.35,2.35]:
		box("Bumper",Vector3(0,.47,z),Vector3(1.78,.13,.09),silver)
	box("LightbarMount",Vector3(0,1.70,.12),Vector3(1.25,.09,.32),black)
	for side in [-1.0,1.0]:
		beacons.append(box("AmberBeacon",Vector3(side*.39,1.81,.12),Vector3(.47,.16,.29),material("ff990c")))

func _process(delta: float) -> void:
	clock += delta
	for i in range(beacons.size()):
		var mat := beacons[i].material_override as StandardMaterial3D
		mat.emission_enabled = flashing and int(clock*8.0)%2 == i
		mat.emission = Color("ffb020")
		mat.emission_energy_multiplier = 3.0

func material(colour: String, roughness: float = .5, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(colour)
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

func box(label: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	add_child(node)
	return node

func loft(label: String, rings: Array, mat: Material) -> void:
	var vertices: Array[Vector3] = []
	for ring in rings:
		var y: float = ring[0]
		var w: float = ring[1]
		var front: float = ring[2]
		var rear: float = ring[3]
		for p in [Vector3(-w+.12,y,front),Vector3(w-.12,y,front),Vector3(w,y,front+.14),Vector3(w,y,rear-.14),Vector3(w-.12,y,rear),Vector3(-w+.12,y,rear),Vector3(-w,y,rear-.14),Vector3(-w,y,front+.14)]:
			vertices.append(p)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in range(rings.size()-1):
		for side in range(8):
			var a := level*8+side
			var b := level*8+(side+1)%8
			for index in [a,b,a+8,b,b+8,a+8]:
				surface.add_vertex(vertices[index])
	var top := (rings.size()-1)*8
	for i in range(1,7):
		for index in [top,top+i,top+i+1]:
			surface.add_vertex(vertices[index])
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = surface.commit()
	node.material_override = mat
	add_child(node)
