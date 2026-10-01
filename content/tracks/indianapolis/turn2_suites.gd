@tool
extends Node3D
## Approximate Turn 2 VIP Suites from supplied/online exterior photos.
## Local -X faces the track, Z follows the backstretch. Material-batched scenery.
var batches: Dictionary = {}

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/indianapolis/geometry.json"))
	var pose: Dictionary = data.turn2_suites
	position = Vector3(pose.position[0],pose.position[1],pose.position[2])
	rotation_degrees.y = float(pose.heading_deg)
	for spec in [["Concrete","939489"],["Slabs","c0c2b7"],["Glass","303f3e"],
		["GlassLight","526765"],["Frames","a4aaa0"],["Steel","5e625b"],
		["Chairs","e0dfd1"],["Doors","534d43"],["Roof","b6b9ad"]]:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(spec[1])
		material.roughness = .4 if spec[0] in ["Glass","GlassLight"] else .85
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		builder.set_smooth_group(-1)
		builder.set_material(material)
		batches[spec[0]] = builder
	_box("Slabs",Vector3(0,.15,0),Vector3(19,.3,136))
	_box("Concrete",Vector3(1,8.1,0),Vector3(13,16.2,120))
	# Low service level below the three continuous balcony floors.
	for z in range(-55,56,5):
		_box("Doors",Vector3(-5.55,1.4,z),Vector3(.15,2.5,2))
	for floor_index in range(3):
		var y := 3.0+floor_index*4.3
		_box("Slabs",Vector3(-.9,y,0),Vector3(16.8,.35,121))
		_box("Slabs",Vector3(-9.25,y+.14,0),Vector3(.25,.55,121))
		# Recessed glazing with repeated suite doors and balcony dividers.
		for bay in range(20):
			var z := -57.0+bay*6
			for pane in range(3):
				_box("GlassLight" if (bay+pane)%4 == 0 else "Glass",Vector3(-5.57,y+2.03,z-2+pane*2),Vector3(.13,3.55,1.86))
				_box("Frames",Vector3(-5.68,y+2.03,z-3+pane*2),Vector3(.14,3.7,.1))
			_box("Frames",Vector3(-5.69,y+1.14,z),Vector3(.12,.09,5.9))
			_box("Steel",Vector3(-8.85,y+2.1,z-3),Vector3(.17,4.2,.17))
			_box("Frames",Vector3(-7.3,y+.72,z-3),Vector3(3.5,1.25,.08))
			for chair in range(5):
				_chair(Vector3(-8.0,y+.26,z-2.4+chair*1.05))
		# Fine pale balcony railings with closely spaced vertical pickets.
		for height in [.18,.63,1.18]:
			_box("Frames",Vector3(-9.2,y+height,0),Vector3(.09,.08,120))
		for z in range(-120,121):
			_box("Frames",Vector3(-9.2,y+.68,z*.5),Vector3(.06,1.05,.06))
		for side in [-1.0,1.0]:
			_box("Frames",Vector3(-7.3,y+1.18,side*60),Vector3(3.8,.09,.09))
	# Flat overhanging roof and long pale fascia.
	_box("Roof",Vector3(-.8,16.15,0),Vector3(17.5,.4,122))
	_box("Slabs",Vector3(-9.55,16.12,0),Vector3(.18,.7,122))
	for side in [-1.0,1.0]:
		var z: float = side*64
		_box("Concrete",Vector3(1,8.05,z),Vector3(14,16.1,7))
		_box("Roof",Vector3(1,16.25,z),Vector3(14.5,.3,7.5))
		# Glazed stair strip beside each solid end core, visible from the oval.
		_box("GlassLight",Vector3(-6.12,8,z-side*2.1),Vector3(.17,15.6,2.1))
		for y in range(1,17,2):
			_box("Frames",Vector3(-6.25,y,z-side*2.1),Vector3(.12,.12,2.2))
		for dz in [-1.05,1.05]:
			_box("Frames",Vector3(-6.25,8,z-side*2.1+dz),Vector3(.12,16,.12))
		_box("Steel",Vector3(3,16.9,side*49),Vector3(3.5,1.2,5))
	for key in batches:
		var builder: SurfaceTool = batches[key]
		builder.generate_normals()
		var instance := MeshInstance3D.new()
		instance.name = key
		instance.mesh = builder.commit()
		add_child(instance)
	batches.clear()

func _chair(at: Vector3) -> void:
	_box("Chairs",at+Vector3(0,.48,0),Vector3(.56,.09,.53))
	_box("Chairs",at+Vector3(.25,.81,0),Vector3(.07,.62,.53))
	for x in [-.2,.2]:
		for z in [-.2,.2]:
			_box("Chairs",at+Vector3(x,.23,z),Vector3(.045,.46,.045))

func _box(material: String, center: Vector3, size: Vector3) -> void:
	var builder: SurfaceTool = batches[material]
	var corners: Array[Vector3] = []
	for p in [Vector3(-1,-1,-1),Vector3(1,-1,-1),Vector3(1,1,-1),Vector3(-1,1,-1),
		Vector3(-1,-1,1),Vector3(1,-1,1),Vector3(1,1,1),Vector3(-1,1,1)]:
		corners.append(center+p*size*.5)
	for i in [0,1,2,0,2,3,5,4,7,5,7,6,4,0,3,4,3,7,1,5,6,1,6,2,3,2,6,3,6,7,4,5,1,4,1,0]:
		builder.add_vertex(corners[i])
