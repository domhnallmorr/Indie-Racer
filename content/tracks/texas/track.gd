@tool
extends Node3D
## Surfaces and collisions share exactly the same imported sample geometry.
## Build visuals in the 3D editor too; physics is only needed during play.
var camera_positions: Array = []
var bank_focus := Vector3.ZERO
var pit_focus := Vector3.ZERO
var overview_distance := 1350.0

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/texas/geometry.json"))
	camera_positions = data.cameras
	bank_focus = _v(data.bank_focus)
	pit_focus = _v(data.pit_focus)
	for strip in data.strips:
		_build_strip(strip)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1500,1100)
	ground.mesh = plane
	ground.position.y = -.2
	ground.material_override = _material("#50643a")
	add_child(ground)
	if not Engine.is_editor_hint():
		ground.create_trimesh_collision()
	var session: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/texas/session.json"))
	for box in session.pit_boxes:
		var label := Label3D.new()
		label.text = str(session.pit_boxes.find(box)+1)
		label.position = _v(box.position)+Vector3.UP*.04
		label.rotation_degrees = Vector3(-90,float(box.heading_deg),0)
		label.pixel_size = .045
		add_child(label)

func _material(colour: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(colour)
	mat.roughness = .95
	return mat

func _build_strip(data: Dictionary) -> void:
	var rows: Array = data.rows
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mat := _material(data.colour)
	if data.get("double_sided",false):
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	builder.set_material(mat)
	if data.name == "PitSeparationGrass":
		var turf := ShaderMaterial.new()
		turf.shader = preload("res://content/tracks/texas/infield_surface.gdshader")
		turf.set_shader_parameter("surface_kind",1)
		turf.set_shader_parameter("base_color",Color("526c39"))
		turf.set_shader_parameter("secondary_color",Color("798354"))
		builder.set_material(turf)
	for i in range(rows.size()-1):
		for j in range(rows[i].size()-1):
			var a := _v(rows[i][j])
			var b := _v(rows[i+1][j])
			var c := _v(rows[i+1][j+1])
			var d := _v(rows[i][j+1])
			for p in [a,c,b,a,d,c]:
				builder.set_uv(Vector2(p.x,p.z))
				builder.add_vertex(p)
	builder.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = data.name
	instance.mesh = builder.commit()
	add_child(instance)
	if data.collision and not Engine.is_editor_hint():
		instance.create_trimesh_collision()
		if data.name == "RacingSurface":
			# This mesh contains only the road skin; barriers are separate bodies.
			# Vehicle contact handling can verify spurious lateral triangle-edge
			# normals against the walkable face before applying a wall impulse.
			instance.get_child(0).set_meta("drivable_surface",true)
		if data.get("double_sided",false):
			var shape: ConcavePolygonShape3D = instance.get_child(0).get_child(0).shape
			shape.backface_collision = true

func _v(p: Array) -> Vector3:
	return Vector3(p[0],p[1],p[2])
