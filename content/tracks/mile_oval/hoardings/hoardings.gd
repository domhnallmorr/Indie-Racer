@tool
extends Node3D
## Shared sponsor set: turn 2 exit and turn 3 entrance, 24 x 8 m panels.
const STRAIGHT := (1609.344 - TAU * 125.0) / 2.0
const ARC := PI * 125.0
const SPACING := 27.0
const LOGOS = [preload("res://content/tracks/mile_oval/hoardings/fedex_1994.svg"), preload("res://content/tracks/mile_oval/hoardings/mcdonalds_1993.svg"), preload("res://content/tracks/mile_oval/hoardings/sears.png"), preload("res://content/tracks/mile_oval/hoardings/bosch.png"), preload("res://content/tracks/mile_oval/hoardings/journal_sentinel.svg"), preload("res://content/tracks/mile_oval/hoardings/ppg.svg"), preload("res://content/tracks/mile_oval/hoardings/unifirst.png"), preload("res://content/tracks/mile_oval/hoardings/goodyear_wordmark.png"), preload("res://content/tracks/mile_oval/hoardings/miller_lite.png")]
const NAMES = ["FedEx", "McDonalds", "Sears", "Bosch", "JournalSentinel", "PPG", "UniFirst", "Goodyear", "MillerLite"]
const SIZES = [Vector2(21,6.57), Vector2(7,7), Vector2(21,5.04), Vector2(21,5.76), Vector2(22,1.63), Vector2(8.5,6.59), Vector2(16,5.33), Vector2(23.6,6.31), Vector2(8.5,6.8)]
# UV windows remove source padding without modifying the downloaded artwork.
const REGIONS = [Rect2(0,0,1,1),Rect2(0,0,1,1),Rect2(0,0,1,1),Rect2(0,.28,1,.49),Rect2(0,0,1,1),Rect2(0,0,1,1),Rect2(.05,.35,.9,.3),Rect2(.008,.267,.985,.468),Rect2(.04,.145,.92,.735)]

func _ready() -> void:
	# Build once, then duplicate to share mesh and material resources.
	for i in range(NAMES.size()):
		var board := _make_board(i)
		board.name = "Turn2_" + NAMES[i]
		add_child(board)
		_place(board, STRAIGHT + 230.0 + SPACING * i)
		var repeat := board.duplicate() as Node3D
		repeat.name = "Turn3_" + NAMES[i]
		add_child(repeat)
		_place(repeat, 2.0 * STRAIGHT + ARC + 60.0 + SPACING * i)

func _place(board: Node3D, distance: float) -> void:
	var center: Vector3
	var outward: Vector3
	if distance < STRAIGHT + ARC:
		var angle := -PI / 2.0 + (distance - STRAIGHT) / 125.0
		outward = Vector3(cos(angle), 0, -sin(angle))
		center = Vector3(STRAIGHT / 2.0, 0, 0) + outward * 125.0
	elif distance < 2.0 * STRAIGHT + ARC:
		outward = Vector3(0, 0, -1)
		center = Vector3(STRAIGHT / 2.0 - (distance - STRAIGHT - ARC), 0, -125)
	else:
		var angle := PI / 2.0 + (distance - 2.0 * STRAIGHT - ARC) / 125.0
		outward = Vector3(cos(angle), 0, -sin(angle))
		center = Vector3(-STRAIGHT / 2.0, 0, 0) + outward * 125.0
	board.position = center + outward * 17.0
	board.rotation.y = atan2(-outward.x, -outward.z)

func _make_board(i: int) -> Node3D:
	var board := Node3D.new()
	var color := Color.WHITE
	if i == 1:
		color = Color("cf171f")
	elif i == 7:
		color = Color("20549a")
	_box(board, "Panel", Vector3(24,8,.5), Vector3(0,8,0), color)
	for x in [-8.0,8.0]:
		_box(board, "Post", Vector3(.45,8,.45), Vector3(x,4,-.4), Color("454b50"))
	var logo := MeshInstance3D.new()
	logo.name = "Logo"
	var quad := QuadMesh.new()
	quad.size = SIZES[i]
	logo.mesh = quad
	logo.position = Vector3(0,8.7 if i == 6 else 8.0,.26)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = LOGOS[i]
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.roughness = 1.0
	mat.uv1_scale = Vector3(REGIONS[i].size.x, REGIONS[i].size.y, 1)
	mat.uv1_offset = Vector3(REGIONS[i].position.x, REGIONS[i].position.y, 0)
	logo.material_override = mat
	board.add_child(logo)
	if i == 6:
		var label := Label3D.new()
		label.name = "UniFirstName"
		label.text = "UniFirst"
		label.font_size = 96
		label.pixel_size = .014
		label.modulate = Color("365d67")
		label.outline_size = 0
		label.position = Vector3(0,5.2,.27)
		board.add_child(label)
	return board

func _box(parent: Node3D, label: String, size: Vector3, location: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = location
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	instance.material_override = mat
	parent.add_child(instance)
