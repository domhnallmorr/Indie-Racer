@tool
extends Node3D
## Reusable station: all equipment remains behind the infield pit wall.
var station_index := 0
var team_colour := Color("ab2431")
static var shared_materials: Dictionary = {}
var metal: StandardMaterial3D
var dark: StandardMaterial3D
var red: StandardMaterial3D
var cloth: StandardMaterial3D

func _ready() -> void:
	metal = _material("8b9092",0.42)
	dark = _material("25292c",0.75)
	red = StandardMaterial3D.new()
	red.albedo_color = team_colour
	red.roughness = .8
	cloth = _material("dfddd4",0.94)
	_box("GroundMat",Vector3(0,.008,0),Vector3(5.15,.015,3.25),_material("484c4b",1.0))
	for x in [-2.6,2.6]:
		for z in [-1.7,1.7]:
			_box("Foot",Vector3(x,0.035,z),Vector3(.22,.07,.22),dark)
			_rod(Vector3(x,.07,z),Vector3(x,2.42,z),.026,metal)
			_rod(Vector3(x,1.95,z),Vector3(x-signf(x)*.48,2.42,z),.017,metal)
		_rod(Vector3(x,2.38,-1.7),Vector3(x,2.38,1.7),.025,metal)
	for z in [-1.7,1.7]:
		_rod(Vector3(-2.6,2.38,z),Vector3(2.6,2.38,z),.025,metal)
		_box("Valance",Vector3(0,2.37,z),Vector3(5.4,.24,.04),red)
	for x in [-2.7,2.7]:
		_box("EndValance",Vector3(x,2.37,0),Vector3(.04,.24,3.4),red)
	_roof()
	_box("DeskTop",Vector3(.0,1.05,.85),Vector3(2.5,.075,.72),dark)
	for x in [-1.1,1.1]:
		for z in [.58,1.10]:
			_rod(Vector3(x,.03,z),Vector3(x,1.02,z),.025,metal)
	for i in range(3):
		_monitor(-.83+i*.8)
	_box("Radio",Vector3(1.48,1.17,.87),Vector3(.30,.23,.25),dark)
	_rod(Vector3(1.48,1.28,.87),Vector3(1.48,1.58,.87),.009,dark)
	_box("TimingRack",Vector3(-1.8,.47,.77),Vector3(.52,.87,.6),dark)
	for y in [.25,.43,.61,.79]:
		_box("RackSlot",Vector3(-1.8,y,1.077),Vector3(.44,.018,.012),metal)
	_box("ToolChest",Vector3(2.0,.48,-.85),Vector3(.85,.8,.55),red)
	_box("ChestTop",Vector3(2.0,.905,-.85),Vector3(.9,.055,.60),dark)
	for y in [.25,.40,.55,.70,.82]:
		_box("DrawerHandle",Vector3(2.0,y,-.565),Vector3(.59,.019,.025),metal)
	for x in [1.68,2.32]:
		for z in [-1.03,-.67]:
			_box("Caster",Vector3(x,.07,z),Vector3(.10,.14,.08),dark)
	for x in [-.72,.5]:
		_chair(x,-.9)
	# Routed leads stay within the station footprint.
	for x in [-.83,0,.83]:
		_rod(Vector3(x,1.20,1.1),Vector3(x,.08,.8),.012,dark)
		_rod(Vector3(x,.08,.8),Vector3(-1.8,.08,.77),.012,dark)
	_crew()
	# Alternate the whole working layout, keeping canopy posts and apron clear.
	if station_index % 2 == 1:
		for child in get_children():
			child.position.x *= -1
			if child is MeshInstance3D:
				child.basis = Basis(Vector3.LEFT,Vector3.UP,Vector3.BACK)*child.basis
				# Bake reflections with reversed winding so static batching keeps
				# outward faces and normals, rather than inside-out equipment.
				var mesh := ArrayMesh.new()
				for surface in range(child.mesh.get_surface_count()):
					var arrays: Array = child.mesh.surface_get_arrays(surface).duplicate(true)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
					for v in range(vertices.size()):
						vertices[v] = child.transform*vertices[v]
						normals[v] = (child.basis*normals[v]).normalized()
					arrays[Mesh.ARRAY_VERTEX] = vertices
					arrays[Mesh.ARRAY_NORMAL] = normals
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
					if indices.is_empty():
						for v in range(vertices.size()):
							indices.append(v)
					for v in range(0,indices.size(),3):
						var swap := indices[v]
						indices[v] = indices[v+2]
						indices[v+2] = swap
					arrays[Mesh.ARRAY_INDEX] = indices
					arrays[Mesh.ARRAY_TANGENT] = null
					mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
					mesh.surface_set_material(surface,child.mesh.surface_get_material(surface))
				child.mesh = mesh
				child.transform = Transform3D.IDENTITY

func set_team_colour(colour: Color) -> void:
	team_colour = colour
	if red != null:
		red.albedo_color = colour

func _material(hex: String, roughness: float) -> StandardMaterial3D:
	var key := hex+str(roughness)
	if shared_materials.has(key):
		return shared_materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = roughness
	shared_materials[key] = mat
	return mat

func _box(label: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = pos
	add_child(node)
	return node

func _rod(a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 10
	mesh.material = mat
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = (a+b)/2
	node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	add_child(node)

func _roof() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(cloth)
	var corners := [Vector3(-2.7,2.49,-1.8),Vector3(2.7,2.49,-1.8),Vector3(2.7,2.49,1.8),Vector3(-2.7,2.49,1.8)]
	var ridge := [Vector3(-1.15,3.02,0),Vector3(1.15,3.02,0)]
	for tri in [[corners[0],corners[1],ridge[1]],[corners[0],ridge[1],ridge[0]],[corners[1],corners[2],ridge[1]],[corners[2],corners[3],ridge[0]],[corners[2],ridge[0],ridge[1]],[corners[3],corners[0],ridge[0]]]:
		for p in tri:
			st.add_vertex(p)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "FabricRoof"
	node.mesh = st.commit()
	add_child(node)
	for i in range(4):
		_rod(corners[i],ridge[0 if i == 0 or i == 3 else 1],.018,metal)

func _monitor(x: float) -> void:
	_box("MonitorBase",Vector3(x,1.11,.9),Vector3(.34,.04,.24),dark)
	_box("MonitorStand",Vector3(x,1.21,.94),Vector3(.09,.18,.09),dark)
	_box("CRT",Vector3(x,1.43,.98),Vector3(.57,.43,.40),dark)
	var face := _box("TimingScreen",Vector3(x,1.43,.774),Vector3(.48,.34,.012),_material("101e26",.45))
	var display := _material("ffffff",.7)
	display.albedo_texture = load("res://content/tracks/mile_oval/pit_station/timing_screen.svg")
	display.emission_enabled = true
	display.emission = Color.WHITE
	display.emission_texture = display.albedo_texture
	display.emission_energy_multiplier = .35
	var quad := QuadMesh.new()
	quad.size = Vector2(.47,.33)
	quad.material = display
	var screen := MeshInstance3D.new()
	screen.mesh = quad
	screen.position = face.position+Vector3(0,0,-.008)
	screen.rotation.y = PI
	add_child(screen)
	_box("Keyboard",Vector3(x,1.105,.60),Vector3(.43,.035,.15),dark)
	for row in range(3):
		for key in range(10):
			_box("Key",Vector3(x-.18+key*.04,1.126,.55+row*.04),Vector3(.026,.007,.024),metal)
	for i in range(6):
		_box("Vent",Vector3(x-.17+i*.065,1.47,1.185),Vector3(.026,.18,.009),metal)

func _chair(x: float, z: float) -> void:
	_box("ChairSeat",Vector3(x,.47,z),Vector3(.45,.045,.43),dark)
	_box("ChairBack",Vector3(x,.77,z-.20),Vector3(.45,.35,.045),red)
	for side in [-.20,.20]:
		_rod(Vector3(x+side,.03,z-.23),Vector3(x+side,.53,z+.21),.016,metal)
		_rod(Vector3(x+side,.03,z+.23),Vector3(x+side,.92,z-.21),.016,metal)

func _crew() -> void:
	var texture = load("res://content/tracks/mile_oval/pit_station/crew.png")
	if texture == null:
		return
	for i in range(3):
		var sprite := Sprite3D.new()
		sprite.name = "Engineer%d" % (i+1)
		sprite.texture = texture
		sprite.hframes = 3
		sprite.frame = (i+station_index)%3
		sprite.pixel_size = 1.85/texture.get_height()
		sprite.position = [Vector3(-1.7,.925,-.2),Vector3(.3,.925,.0),Vector3(1.7,.925,.1)][i]
		if station_index > 0:
			sprite.position.z -= float((station_index+i)%3)*.12
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.shaded = true
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(sprite)
