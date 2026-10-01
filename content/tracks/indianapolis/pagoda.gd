@tool
extends Node3D
## Photo-inspired Pagoda, centred on start/finish. Batched scenery, no road collision.
var batches: Dictionary = {}

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/indianapolis/geometry.json"))
	var pose: Dictionary = data.pagoda
	position = Vector3(pose.position[0],pose.position[1],pose.position[2])
	rotation_degrees.y = float(pose.heading_deg)
	for spec in [["Concrete","b4b4a5"],["Steel","384947"],["Roof","66736b"],
			["Glass","226661"],["Window","43847b"],["Rail","a7b2a8"],["Sign","16272a"],
			["White","e1e2cf"],["Red","af3433"],["Blue","263e68"],["Yellow","d3ae3b"]]:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(spec[1])
		material.roughness = .48 if spec[0] in ["Glass","Window"] else .8
		material.metallic = .25 if spec[0] in ["Glass","Window","Steel"] else 0
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		builder.set_smooth_group(-1)
		builder.set_material(material)
		batches[spec[0]] = builder
	_box("Concrete",Vector3(0,.5,0),Vector3(32,1,66))
	# Each upper storey steps inward to create the characteristic pagoda silhouette.
	var levels := [[1.0,8.0,27.0,58.0],[9.0,8.0,23.0,42.0],
		[17.0,8.0,21.0,35.0],[25.0,8.0,19.0,28.0],[33.0,7.0,16.0,22.0]]
	for level in levels:
		_floor(level[0],level[1],level[2],level[3])
	# Roof-level timing fascia and the broad, separate crowning canopy.
	_box("Sign",Vector3(8.15,38,0),Vector3(.25,2.8,22))
	_text("1   2   3   4   5   6   7   8",Vector3(8.32,37.7,0),90,.021)
	_text("INDIANAPOLIS",Vector3(8.33,39,0),90,.024)
	_box("Concrete",Vector3(0,41,0),Vector3(9,2,11))
	_roof(43,15,22)
	for z in [-6.0,0.0,6.0]:
		_box("Rail",Vector3(0,46,z),Vector3(.12,6,.12))
		_flag(Vector3(0,48,z),"Blue" if z < 0 else ("Red" if z == 0 else "Yellow"))
	# Monumental concrete side cores, glazing and horizontal floor bands remain visible
	# from both directions down the straight.
	for side in [-1.0,1.0]:
		_box("Concrete",Vector3(-1,23,side*11.15),Vector3(6,32,.4))
		_box("White",Vector3(-1,37,side*11.42),Vector3(5,4,.16))
		_text("IMS",Vector3(-1,37,side*11.55),0 if side > 0 else 180,.045)
	for key in batches:
		var builder: SurfaceTool = batches[key]
		builder.generate_normals()
		var instance := MeshInstance3D.new()
		instance.name = key
		instance.mesh = builder.commit()
		add_child(instance)
	batches.clear()

func _floor(y: float, height: float, depth: float, width: float) -> void:
	_box("Concrete",Vector3(0,y+height*.5,0),Vector3(depth-1,height,width-1))
	for side in [-1.0,1.0]:
		# Front/back glass curtain walls, with two rows of individual panes.
		for z in range(int(-width*.5)+1,int(width*.5),2):
			for row in range(2):
				_box("Glass" if (z+row)%3 else "Window",Vector3(side*depth*.5,y+1.9+row*3.3,z),Vector3(.16,3.05,1.84))
			_box("Rail",Vector3(side*(depth*.5+.15),y+height*.5,z+1),Vector3(.14,height,.09))
		for x in range(int(-depth*.5)+1,int(depth*.5),2):
			_box("Glass",Vector3(x,y+height*.5,side*width*.5),Vector3(1.8,height-.7,.15))
		# Balcony rails along the frontage and returns.
		_box("Rail",Vector3(side*(depth*.5+2),y+1.2,0),Vector3(.10,.10,width+4))
		_box("Rail",Vector3(side*(depth*.5+2),y+.65,0),Vector3(.08,.08,width+4))
		for z in range(int(-width*.5)-2,int(width*.5)+3,3):
			_box("Rail",Vector3(side*(depth*.5+2),y+.6,z),Vector3(.09,1.2,.09))
			_box("Steel",Vector3(side*(depth*.5+.8),y+height*.5,z),Vector3(.28,height,.28))
			_beam(Vector3(side*(depth*.5+.8),y+height-1.9,z),Vector3(side*(depth*.5+4),y+height-.25,z),.18)
		_box("Rail",Vector3(0,y+1.2,side*(width*.5+2)),Vector3(depth+4,.1,.1))
	_box("Concrete",Vector3(0,y,0),Vector3(depth+4,.38,width+4))
	_roof(y+height,depth+8,width+8)

func _roof(y: float, depth: float, width: float) -> void:
	_box("Steel",Vector3(0,y-.22,0),Vector3(depth,.3,width))
	_box("Roof",Vector3(0,y,0),Vector3(depth+.45,.16,width+.45))
	for z in range(int(-width*.5)+1,int(width*.5),3):
		_box("Steel",Vector3(0,y-.48,z),Vector3(depth,.25,.18))
	for side in [-1.0,1.0]:
		_box("Rail",Vector3(side*depth*.5,y+.12,0),Vector3(.12,.18,width))

func _beam(a: Vector3,b: Vector3,width: float) -> void:
	var delta := b-a
	var basis := Basis.looking_at(delta.normalized(),Vector3.UP)
	_box("Steel",(a+b)*.5,Vector3(width,width,delta.length()),basis)

func _box(material: String, center: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var builder: SurfaceTool = batches[material]
	var corners: Array[Vector3] = []
	for p in [Vector3(-1,-1,-1),Vector3(1,-1,-1),Vector3(1,1,-1),Vector3(-1,1,-1),
		Vector3(-1,-1,1),Vector3(1,-1,1),Vector3(1,1,1),Vector3(-1,1,1)]:
		corners.append(center+basis*(p*size*.5))
	for i in [0,1,2,0,2,3,5,4,7,5,7,6,4,0,3,4,3,7,1,5,6,1,6,2,3,2,6,3,6,7,4,5,1,4,1,0]:
		builder.add_vertex(corners[i])

func _flag(at: Vector3, material: String) -> void:
	# Small offset panels give the flags a folded silhouette without animation cost.
	for i in range(6):
		_box(material,at+Vector3(sin(i*.9)*.22,-.7,i*.42+.21),Vector3(.04,1.4,.43))

func _text(value: String, at: Vector3, yaw: float, scale: float) -> void:
	var label := Label3D.new()
	label.text = value
	label.position = at
	label.rotation_degrees.y = yaw
	label.font_size = 64
	label.pixel_size = scale
	label.outline_size = 0
	add_child(label)
