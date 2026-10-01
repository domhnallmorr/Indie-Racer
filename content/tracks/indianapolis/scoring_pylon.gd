@tool
extends Node3D
## Reference-inspired scoring landmark; displayed order is decorative.

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/indianapolis/geometry.json"))
	var pose: Dictionary = data.scoring_pylon
	var p: Array = pose.position
	position = Vector3(p[0],p[1],p[2])
	rotation_degrees.y = float(pose.heading_deg)
	# Local Z runs along the straight. The narrow mast sits on the divider;
	# the elevated display faces approaching cars and clears the road below.
	_box("Foot",Vector3(.5,.5,2.3),Vector3(0,.25,0),"bcbdb4")
	_box("Mast",Vector3(.34,29,.4),Vector3(0,14.5,0),"a7ada8")
	_box("Display",Vector3(2.15,23,.65),Vector3(0,16,0),"171e22")
	_box("Header",Vector3(2.2,2.1,.69),Vector3(0,28.6,0),"dedfd6")
	_box("Cap",Vector3(2.45,.15,.85),Vector3(0,29.7,0),"697575")
	for side in [-1.0,1.0]:
		var board := Node3D.new()
		board.position = Vector3(0,0,side*.35)
		board.rotation_degrees.y = 0 if side > 0 else 180
		add_child(board)
		_label(board,"IMS",Vector3(0,28.8,.02),.012,Color("17374b"))
		_label(board,"LAP  01",Vector3(0,26.9,.015),.007,Color("f1d58c"))
		for i in range(33):
			_label(board,"%02d  %02d" % [i+1,i+1],Vector3(0,26.05-i*.64,.015),.0065,Color("eeeece"))
	_box("Flagpole",Vector3(.05,3,.05),Vector3(0,31.2,0),"bfc7c8")
	_box("Flag",Vector3(.025,.65,1.1),Vector3(0,32.15,.55),"bf3430")

func _box(title: String, size: Vector3, at: Vector3, colour: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = title
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(colour)
	material.roughness = .85
	instance.material_override = material
	add_child(instance)

func _label(parent: Node3D, value: String, at: Vector3, scale: float, colour: Color) -> void:
	var label := Label3D.new()
	label.text = value
	label.position = at
	label.font_size = 64
	label.pixel_size = scale
	label.modulate = colour
	label.outline_size = 0
	label.no_depth_test = false
	parent.add_child(label)
