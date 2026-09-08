@tool
extends Node3D
## Track-local scenery. Shared 32 x 18 x 9 m roofless wedges.
const STRAIGHT := (1609.344 - TAU * 125.0) / 2.0
const ATLAS = preload("res://content/tracks/mile_oval/grandstands/crowd_support_atlas.png")

func _ready() -> void:
	# Centre the original 260 m main stand on the finish line.
	for part in get_parent().get_node("Geometry").get_children():
		if str(part.name).begins_with("Grandstand"):
			part.position.x = STRAIGHT * 0.15
	var shared_mesh := _stand_mesh()
	for i in range(5):
		_place_stand("Turn4Stand%d" % (i + 1), -70.0 + i * 44.0, shared_mesh)
		_place_stand("Turn1Stand%d" % (i + 1), STRAIGHT + 20.0 + i * 40.0, shared_mesh)

func _place_stand(stand_name: String, distance: float, shared_mesh: ArrayMesh) -> void:
	var center: Vector3
	var outward: Vector3
	var elevation: float = 0.0
	const BANK_HEIGHT := 3.5  # Adjust this to match your track's outer wall elevation in meters
	const TRANSITION_LEN := 30.0 # Length of the banking transition onto the straight

	if distance < 0.0:
		var angle := -PI / 2.0 + distance / 125.0
		outward = Vector3(cos(angle), 0, -sin(angle))
		center = Vector3(-STRAIGHT / 2.0, 0, 0) + outward * 125.0
		# Fully banked in the turn, smoothly tapers as distance approaches 0
		elevation = clampf(-distance / TRANSITION_LEN, 0.0, 1.0) * BANK_HEIGHT
	elif distance > STRAIGHT:
		var angle := -PI / 2.0 + (distance - STRAIGHT) / 125.0
		outward = Vector3(cos(angle), 0, -sin(angle))
		center = Vector3(STRAIGHT / 2.0, 0, 0) + outward * 125.0
		# Smoothly ramps up as it enters the turn past STRAIGHT
		elevation = clampf((distance - STRAIGHT) / TRANSITION_LEN, 0.0, 1.0) * BANK_HEIGHT
	else:
		outward = Vector3(0, 0, 1)
		center = Vector3(-STRAIGHT / 2.0 + distance, 0, 125)
		elevation = 0.0

	var stand := MeshInstance3D.new()
	stand.name = stand_name
	stand.mesh = shared_mesh
	
	# Apply elevation to the vertical position
	stand.position = center + outward * 12.0
	stand.position.y = elevation
	stand.rotation.y = atan2(outward.x, outward.z)
	add_child(stand)

func _stand_mesh() -> ArrayMesh:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ATLAS
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(mat)
	var a := Vector3(-16, 0, 0)
	var b := Vector3(16, 0, 0)
	var c := Vector3(-16, 9, 18)
	var d := Vector3(16, 9, 18)
	var e := Vector3(-16, 0, 18)
	var f := Vector3(16, 0, 18)
	# Crowd rows run across the slope; heads face uphill in the texture.
	_triangle(surface, [a, c, b], [Vector2(0, .495), Vector2(0, .003), Vector2(1, .495)])
	_triangle(surface, [b, c, d], [Vector2(1, .495), Vector2(0, .003), Vector2(1, .003)])
	_triangle(surface, [a, e, c], [Vector2(0, .997), Vector2(1, .997), Vector2(1, .505)])
	_triangle(surface, [b, d, f], [Vector2(0, .997), Vector2(1, .505), Vector2(1, .997)])
	_triangle(surface, [e, f, c], [Vector2(0, .997), Vector2(1, .997), Vector2(0, .505)])
	_triangle(surface, [f, d, c], [Vector2(1, .997), Vector2(1, .505), Vector2(0, .505)])
	surface.generate_normals()
	return surface.commit()

func _triangle(surface: SurfaceTool, vertices: Array, uvs: Array) -> void:
	for i in range(3):
		surface.set_uv(uvs[i])
		surface.add_vertex(vertices[i])
