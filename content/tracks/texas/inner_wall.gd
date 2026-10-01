@tool
extends Node3D
## Infield boundary, behind pit stalls; never separates pit road from the track.
const HEIGHT := 1.15
const WIDTH := .5
const WALL_SHADER = preload("res://content/tracks/mile_oval/surface/walls.gdshader")
var _material: ShaderMaterial

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/texas/geometry.json"))
	var rows: Array = []
	for strip in data.strips:
		if strip.name == "Apron":
			rows = strip.rows
	if rows.is_empty():
		return
	_material = ShaderMaterial.new()
	_material.shader = WALL_SHADER
	_material.set_shader_parameter("use_wall_uv",true)
	_material.set_shader_parameter("outer_wall",false)
	_material.set_shader_parameter("world_to_track",global_transform.affine_inverse())
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(_material)
	var previous: Array[Vector3] = []
	var distance := 0.0
	for row in rows:
		var front := _v(row[-1])
		var inward := (front-_v(row[0])).normalized()
		var back := front+inward*WIDTH
		# Extend below the grass plane so the wall has no visible gap underneath.
		var section: Array[Vector3] = [front-Vector3.UP*.25,back-Vector3.UP*.25,
			back+Vector3.UP*HEIGHT,front+Vector3.UP*HEIGHT,front-Vector3.UP*.25]
		if not previous.is_empty():
			var next_distance := distance+previous[0].distance_to(section[0])
			for j in range(4):
				var vertices := [previous[j],section[j],section[j+1],previous[j+1]]
				var uvs := [Vector2(distance,previous[j].y),Vector2(next_distance,section[j].y),
					Vector2(next_distance,section[j+1].y),Vector2(distance,previous[j+1].y)]
				for index in [0,2,1,0,3,2]:
					builder.set_uv(uvs[index])
					builder.add_vertex(vertices[index])
			distance = next_distance
		previous = section
	# Fit whole blocks around the loop so the seam joins cleanly.
	_material.set_shader_parameter("block_width_m",distance/roundf(distance/6.5))
	builder.generate_normals()
	var wall := MeshInstance3D.new()
	wall.name = "ConcreteWall"
	wall.mesh = builder.commit()
	add_child(wall)
	if not Engine.is_editor_hint():
		wall.create_trimesh_collision()
		var shape: ConcavePolygonShape3D = wall.get_child(0).get_child(0).shape
		shape.backface_collision = true

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and _material:
		_material.set_shader_parameter("world_to_track",global_transform.affine_inverse())

func _v(p: Array) -> Vector3:
	return Vector3(p[0],p[1],p[2])
