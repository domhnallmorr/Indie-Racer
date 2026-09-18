@tool
extends Node3D
## Track-local metres: finish X + 6; inner wall Z=87 minus 10.
func _ready() -> void:
	position = Vector3(67.79594, -0.1, 77.0)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("c2c6ca")
	metal.metallic = 0.75
	metal.roughness = 0.3
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color("96958c")
	_cylinder("Footing", 0.65, 0.65, 0.3, 0.15, concrete)
	_cylinder("Pole", 0.09, 0.19, 22.0, 11.3, metal)
	var ball := SphereMesh.new()
	ball.radius = 0.2
	ball.height = 0.4
	_mesh("Finial", ball, Vector3(0, 22.45, 0), metal)
	# A subdivided vertical cloth, attached along its entire left edge.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(24):
		for x in range(48):
			for corner in [Vector2i(0,0), Vector2i(0,1), Vector2i(1,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)]:
				var uv := Vector2(float(x + corner.x) / 48.0, float(y + corner.y) / 24.0)
				surface.set_uv(uv)
				surface.set_normal(Vector3(0,0,1))
				surface.add_vertex(Vector3(uv.x * 5.7, -uv.y * 3.0, 0))
	var cloth := ShaderMaterial.new()
	cloth.shader = preload("res://content/tracks/mile_oval/flag/flag.gdshader")
	cloth.set_shader_parameter("flag_texture", preload("res://content/tracks/mile_oval/flag/american_flag.svg"))
	var flag := _mesh("AmericanFlag", surface.commit(), Vector3(0.12,21.9,0), cloth)
	flag.custom_aabb = AABB(Vector3(-0.1,-3.5,-0.7),Vector3(6.0,3.7,1.4))
	flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED

func _cylinder(label: String, top: float, bottom: float, height: float, y: float, material: Material) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = 16
	_mesh(label, cylinder, Vector3(0,y,0), material)

func _mesh(label: String, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	add_child(instance)
	return instance
