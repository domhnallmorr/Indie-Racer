@tool
extends Node3D
## The same generated road vertices supply rendering and vehicle collision.
var camera_positions: Array = []
var bank_focus := Vector3.ZERO
var pit_focus := Vector3.ZERO
var overview_distance := 1550.0
var materials: Dictionary = {}

func _ready() -> void:
	_configure_daylight()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/surfers_paradise/geometry.json"))
	camera_positions = data.cameras
	bank_focus = _v(data.bank_focus)
	pit_focus = _v(data.pit_focus)
	for strip in data.strips:
		_build_strip(strip)
	for patch in data.get("patches",[]):
		_build_patch(patch)
	# Abutting land/beach/water, not overlapping kilometre-sized planes. Even
	# tiny height gaps would z-fight in the distant overview camera.
	_box("CityGround",Vector3(0,-.65,-1250),Vector3(6500,.8,3200),"#91998b",true)
	_box("Beach",Vector3(0,-.32,450),Vector3(6500,.2,200),"#d7c797")
	_box("PacificOcean",Vector3(0,-.6,3300),Vector3(9000,.2,5500),"#398d9b")
	for z in [554,575,609,652]:
		_box("Surf",Vector3(0,-.28,z),Vector3(6500,.025,2.5),"#b5d7cb")
	for building in data.buildings:
		_building(building)
	for palm in data.palms:
		_palm(palm)
	for board in data.brake_boards:
		var node := Node3D.new()
		node.position = _v(board.position)
		node.rotation.y = deg_to_rad(board.heading_deg)
		add_child(node)
		_box("BrakeBoard",Vector3(0,2,0),Vector3(1.6,1.4,.1),"#eee8d6",false,node)
		_label(str(board.text),Vector3(0,2,.065),.018,Color("#263b48"),node)
	for stand in data.grandstands:
		var node := Node3D.new()
		node.position = _v(stand.position)
		node.rotation.y = deg_to_rad(stand.heading_deg)
		add_child(node)
		for step in range(7):
			_box("GrandstandTier",Vector3(-float(step)*1.15,1+step*.65,0),Vector3(1.2,.4,70),"#aebbbb",false,node)
		_box("GrandstandRoof",Vector3(-4,7,0),Vector3(11,.3,74),"#d9d4be",false,node)
		for z in [-33,0,33]:
			_box("StandSupport",Vector3(-7,3.5,z),Vector3(.25,7,.25),"#637578",false,node)
	var pit := Node3D.new()
	pit.position = _v(data.pit_building.position)
	pit.rotation.y = deg_to_rad(data.pit_building.heading_deg)
	add_child(pit)
	_box("PitGarages",Vector3(0,2.5,0),Vector3(14,5,250),"#d7d4c5",false,pit)
	_box("PitRoof",Vector3(-1,5.3,0),Vector3(17,.5,255),"#d2dcd9",false,pit)
	for z in range(-120,125,9):
		_box("GarageDoor",Vector3(7.02,1.65,z),Vector3(.06,3.1,6.7),"#3e5863",false,pit)
	var gantry := Node3D.new()
	gantry.position = _v(data.finish_gantry.position)
	gantry.rotation.y = deg_to_rad(data.finish_gantry.heading_deg)
	add_child(gantry)
	for x in [-11,11]:
		_box("GantryLeg",Vector3(x,4,0),Vector3(.5,8,.5),"#667b81",false,gantry)
	_box("FinishGantry",Vector3(0,7.5,0),Vector3(23,2,.55),"#244b5c",false,gantry)
	_label("SURFERS PARADISE  •  1995",Vector3(0,7.5,.3),.031,Color("#f6e4aa"),gantry)
	_fence(data.fences)
	for rows in data.get("extra_fences",[]):
		_fence(rows,false)
	var session: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/surfers_paradise/session.json"))
	for i in range(session.pit_boxes.size()):
		var box: Dictionary = session.pit_boxes[i]
		var marker := Node3D.new()
		marker.position = _v(box.position)
		marker.rotation.y = deg_to_rad(box.heading_deg)
		add_child(marker)
		_label(str(i+1),Vector3(-2.3,2,0),.025,Color("#ffe1a1"),marker)

func _configure_daylight() -> void:
	if Engine.is_editor_hint():
		return
	var world := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world == null:
		return
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#4d86b0")
	sky_material.sky_horizon_color = Color("#c0d7db")
	sky_material.ground_bottom_color = Color("#849485")
	sky_material.ground_horizon_color = Color("#c0d7db")
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d6e1e5")
	environment.ambient_light_energy = .3
	world.environment = environment
	var sun := get_parent().get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_energy = .8

func _material(colour: String) -> StandardMaterial3D:
	if not materials.has(colour):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(colour)
		mat.roughness = .93
		materials[colour] = mat
	return materials[colour]

func _build_strip(data: Dictionary) -> void:
	var rows: Array = data.rows
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := _material(data.colour)
	if data.get("double_sided",false):
		mat = mat.duplicate()
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	builder.set_material(mat)
	for i in range(rows.size()-1):
		for j in range(rows[i].size()-1):
			var a := _v(rows[i][j])
			var b := _v(rows[i+1][j])
			var c := _v(rows[i+1][j+1])
			var d := _v(rows[i][j+1])
			for p in [a,c,b,a,d,c]:
				builder.add_vertex(p)
	builder.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = data.name
	instance.mesh = builder.commit()
	add_child(instance,true)
	if data.collision and not Engine.is_editor_hint():
		instance.create_trimesh_collision()
		if data.name in ["RacingSurface","PitRoad"] or data.get("drivable",false):
			instance.get_child(0).set_meta("drivable_surface",true)
		if data.get("double_sided",false):
			var shape: ConcavePolygonShape3D = instance.get_child(0).get_child(0).shape
			shape.backface_collision = true

func _build_patch(data: Dictionary) -> void:
	var outline := PackedVector2Array()
	for p in data.points:
		outline.append(Vector2(p[0],p[2]))
	var indices := Geometry2D.triangulate_polygon(outline)
	if indices.is_empty():
		push_error("Cannot triangulate landscape patch: "+str(data.name))
		return
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(_material(data.colour))
	for i in indices:
		builder.add_vertex(_v(data.points[i]))
	builder.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = data.name
	instance.mesh = builder.commit()
	# Player surface classification uses the Ground prefix, including repeats.
	add_child(instance,true)
	if data.collision and not Engine.is_editor_hint():
		instance.create_trimesh_collision()

func _box(title: String, at: Vector3, size: Vector3, colour: String, collision := false, parent: Node3D = self) -> void:
	var instance := MeshInstance3D.new()
	instance.name = title
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(colour)
	instance.mesh = mesh
	instance.position = at
	parent.add_child(instance)
	if collision and not Engine.is_editor_hint():
		instance.create_trimesh_collision()

func _label(text: String, at: Vector3, scale: float, colour: Color, parent: Node3D) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.pixel_size = scale
	label.font_size = 44
	label.modulate = colour
	label.outline_size = 0
	parent.add_child(label)

func _building(data: Dictionary) -> void:
	var pos := _v(data.position)
	var size := _v(data.size)
	_box("Hotel",pos+Vector3.UP*size.y*.5,size,data.colour)
	_box("HotelCrown",pos+Vector3.UP*(size.y+.6),Vector3(size.x+1,1.2,size.z+1),data.accent)
	# Repeated balcony bands read at speed without texture downloads.
	for floor_index in range(1,int(size.y/3.5)):
		_box("Balcony",pos+Vector3.UP*(floor_index*3.5),Vector3(size.x+.65,.30,size.z+.65),data.accent)
	for x in [-.36,0,.36]:
		_box("WindowStack",pos+Vector3(x*size.x,size.y*.5,size.z*.5+.04),Vector3(size.x*.16,size.y-3,.07),"#456873")
		_box("WindowStack",pos+Vector3(x*size.x,size.y*.5,-size.z*.5-.04),Vector3(size.x*.16,size.y-3,.07),"#456873")

func _palm(data: Dictionary) -> void:
	var pos := _v(data.position)
	var height: float = data.height
	var trunk := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = .16
	mesh.bottom_radius = .3
	mesh.height = height
	mesh.radial_segments = 6
	mesh.material = _material("#85735b")
	trunk.mesh = mesh
	trunk.position = pos+Vector3.UP*height*.5
	add_child(trunk)
	var leaf := SurfaceTool.new()
	leaf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := _material("#476c49").duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaf.set_material(mat)
	for i in range(7):
		var angle: float = data.angle+i*TAU/7
		var direction := Vector3(cos(angle),0,sin(angle))
		var side := direction.cross(Vector3.UP)*.65
		var start := pos+Vector3.UP*height
		var middle := start+direction*2.0+Vector3.UP*.65
		var end := start+direction*4.3-Vector3.UP*1.4
		for p in [start,middle+side,middle-side,middle-side,middle+side,end]:
			leaf.add_vertex(p)
	leaf.generate_normals()
	var crown := MeshInstance3D.new()
	crown.mesh = leaf.commit()
	add_child(crown)

func _fence(rows: Array, closed := true) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_material(_material("#586b70"))
	for i in range(rows.size()):
		var a := _v(rows[i][0])
		var b := _v(rows[i][1])
		st.add_vertex(a)
		st.add_vertex(b)
		if not closed and i==rows.size()-1:
			continue
		var next := (i+1)%rows.size()
		for f in [.25,.5,.75,1.0]:
			st.add_vertex(a.lerp(b,f))
			st.add_vertex(_v(rows[next][0]).lerp(_v(rows[next][1]),f))
	var fence := MeshInstance3D.new()
	fence.name = "CatchFence"
	fence.mesh = st.commit()
	add_child(fence)

func _v(p: Array) -> Vector3:
	return Vector3(p[0],p[1],p[2])
