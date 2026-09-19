@tool
extends Node3D
## Material-only override: imported mesh and physics remain intact.
var material: ShaderMaterial
var grass_material: ShaderMaterial
var wall_materials: Array[ShaderMaterial] = []
func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = preload("res://content/tracks/mile_oval/surface/asphalt.gdshader")
	material.set_shader_parameter("track_origin",get_parent().global_position)
	material.set_shader_parameter("racing_line_map",_racing_line_texture())
	grass_material = ShaderMaterial.new()
	grass_material.shader = preload("res://content/tracks/mile_oval/surface/grass.gdshader")
	grass_material.set_shader_parameter("atlas",preload("res://content/tracks/mile_oval/backstraight/material_atlas.png"))
	grass_material.set_shader_parameter("track_origin",get_parent().global_position)
	for outer in [false, true]:
		var wall_material := ShaderMaterial.new()
		wall_material.shader = preload("res://content/tracks/mile_oval/surface/walls.gdshader")
		wall_material.set_shader_parameter("outer_wall", outer)
		wall_material.set_shader_parameter("world_to_track", get_parent().global_transform.affine_inverse())
		wall_materials.append(wall_material)
	_apply(get_parent().get_node("Geometry"))
func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and material:
		material.set_shader_parameter("track_origin",get_parent().global_position)
		grass_material.set_shader_parameter("track_origin",get_parent().global_position)
		for wall_material in wall_materials:
			wall_material.set_shader_parameter("world_to_track", get_parent().global_transform.affine_inverse())
func _apply(node: Node) -> void:
	if node is MeshInstance3D:
		# Legacy imported standing-start markings; also omitted by the generator.
		if str(node.name).begins_with("GridSlot"):
			node.hide()
		if str(node.name).begins_with("OuterWall"):
			node.material_override = wall_materials[1]
		elif str(node.name).begins_with("InnerWall") or str(node.name).begins_with("PitSeparator"):
			node.material_override = wall_materials[0]
	if node is MeshInstance3D and str(node.name).begins_with("Ground"):
		node.material_override = grass_material
	if node is MeshInstance3D and (str(node.name).begins_with("RacingSurface") or str(node.name).begins_with("Apron") or str(node.name).begins_with("PitLane")):
		node.material_override = material
	for child in node.get_children():
		_apply(child)

func _racing_line_texture() -> ImageTexture:
	# Encode the authored AI line's lateral offset at uniform lap distances.
	# A small lookup avoids hundreds of path-segment tests per asphalt pixel.
	const LAP := 1609.344
	const STRAIGHT := (LAP-TAU*125.0)*.5
	const ARC := PI*125.0
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/mile_oval/ai/race_line.json"))
	var samples: Array[Vector2] = []
	for point in data.points:
		var x: float = point[0]
		var z: float = point[2]
		var distance: float
		var lateral: float
		if absf(x) > STRAIGHT*.5:
			var radial := Vector2(x-signf(x)*STRAIGHT*.5,-z)
			var angle := radial.angle()
			if x > 0:
				distance = STRAIGHT+(angle+PI*.5)*125.0
			else:
				if angle < PI*.5:
					angle += TAU
				distance = 2*STRAIGHT+ARC+(angle-PI*.5)*125.0
			lateral = radial.length()-125.0
		else:
			distance = x+STRAIGHT*.5 if z >= 0 else STRAIGHT+ARC+STRAIGHT*.5-x
			lateral = absf(z)-125.0
		samples.append(Vector2(distance,lateral))
	samples.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.x < b.x)
	samples.push_front(Vector2(samples[-1].x-LAP,samples[-1].y))
	samples.append(Vector2(samples[1].x+LAP,samples[1].y))
	var lookup := Image.create(1024,1,false,Image.FORMAT_RGBA8)
	var segment := 0
	for i in range(1024):
		var distance := (i+.5)*LAP/1024.0
		while segment < samples.size()-2 and samples[segment+1].x < distance:
			segment += 1
		var a := samples[segment]
		var b := samples[segment+1]
		var offset := lerpf(a.y,b.y,clampf((distance-a.x)/maxf(b.x-a.x,.0001),0,1))
		lookup.set_pixel(i,0,Color(clampf((offset+10.0)/20.0,0,1),0,0,1))
	return ImageTexture.create_from_image(lookup)
