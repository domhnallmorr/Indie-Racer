@tool
extends Node3D
## Reuse the mile oval's open stands and crowd atlas, in longer, lower bays.
var stands: Array = []
const COLOURS := ["#d94940","#327fd0","#f1cc40","#42935a","#eeeadd","#e98531","#9c65b2"]

func _ready() -> void:
	# Instantiate only the mesh builder; its oval-specific _ready never runs.
	var source = preload("res://content/tracks/mile_oval/grandstands/grandstands.gd").new()
	var crowd_mesh: ArrayMesh = source._stand_mesh()
	source.free()
	var cloth_mesh := _cloth_mesh()
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("#bfc9c7")
	metal.roughness = .6
	var cloth_materials: Array[ShaderMaterial] = []
	for colour in COLOURS:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color(colour),Color(colour)])
		var texture := GradientTexture1D.new()
		texture.width = 2
		texture.gradient = gradient
		var material := ShaderMaterial.new()
		material.shader = preload("res://content/tracks/mile_oval/flag/flag.gdshader")
		material.set_shader_parameter("flag_texture",texture)
		cloth_materials.append(material)
	for i in range(stands.size()):
		var data: Dictionary = stands[i]
		var stand := Node3D.new()
		stand.name = data.id
		stand.position = Vector3(data.position[0],data.position[1],data.position[2])
		stand.rotation.y = deg_to_rad(data.heading_deg)
		stand.set_meta("length_m",data.length_m)
		stand.set_meta("flag_count",data.flag_count)
		add_child(stand,true)
		# Tile 32 m crowd bays rather than stretch the spectators across the stand.
		var bays := ceili(float(data.length_m)/32)
		var bay_width := float(data.length_m)/bays
		for bay in range(bays):
			var crowd := MeshInstance3D.new()
			crowd.name = "CrowdBay"
			crowd.mesh = crowd_mesh
			crowd.position.x = -float(data.length_m)/2+(bay+.5)*bay_width
			crowd.scale = Vector3(bay_width/32,float(data.height_m)/9,float(data.depth_m)/18)
			stand.add_child(crowd,true)
		for flag_index in range(data.flag_count):
			var x: float = -float(data.length_m)/2+4+(float(data.length_m)-8)*flag_index/(data.flag_count-1)
			var pole := MeshInstance3D.new()
			pole.name = "Flagpole"
			var cylinder := CylinderMesh.new()
			cylinder.height = 4
			cylinder.top_radius = .055
			cylinder.bottom_radius = .09
			cylinder.radial_segments = 8
			cylinder.material = metal
			pole.mesh = cylinder
			pole.position = Vector3(x,float(data.height_m)+2,float(data.depth_m)-.35)
			stand.add_child(pole,true)
			var flag := MeshInstance3D.new()
			flag.name = "FlyingFlag"
			flag.mesh = cloth_mesh
			flag.material_override = cloth_materials[(i+flag_index)%COLOURS.size()]
			flag.position = Vector3(x+.06,float(data.height_m)+3.85,float(data.depth_m)-.35)
			flag.custom_aabb = AABB(Vector3(-.1,-2.1,-.65),Vector3(3.5,2.3,1.3))
			flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
			# Shader materials remain separate from static batching, so TIME animates them.
			stand.add_child(flag,true)

func _cloth_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(8):
		for x in range(20):
			for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
				var uv := Vector2(float(x+corner.x)/20,float(y+corner.y)/8)
				surface.set_uv(uv)
				surface.set_normal(Vector3(0,0,1))
				surface.add_vertex(Vector3(uv.x*3.1,-uv.y*1.6,0))
	return surface.commit()
