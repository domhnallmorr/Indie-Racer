@tool
extends Node3D
## Two-by-two water-barrel cushion ahead of the pit separator's exposed end.
## Static collision only; water displacement / crushing is not simulated.
var wall_start_x := -130.0
const SPACING := 0.64
const HEIGHT := 0.94

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/mile_oval/session.json"))
	wall_start_x = float(data.pit_speed_zone.polygon_xz[0][0])
	for point in data.pit_speed_zone.polygon_xz:
		wall_start_x = minf(wall_start_x,float(point[0]))
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color("ed650b")
	orange.roughness = 0.68
	var black := StandardMaterial3D.new()
	black.albedo_color = Color("191b1c")
	black.roughness = 0.8
	# Shared lathed meshes include the rolled base, waist bands and lid lip.
	var body := _lathe([
		Vector2(0.265,0.025), Vector2(0.292,0.045), Vector2(0.305,0.10),
		Vector2(0.303,0.24), Vector2(0.315,0.255), Vector2(0.315,0.28),
		Vector2(0.304,0.295), Vector2(0.31,0.59), Vector2(0.319,0.605),
		Vector2(0.319,0.635), Vector2(0.307,0.65), Vector2(0.299,0.845),
		Vector2(0.286,0.875), Vector2(0.286,0.895)], orange)
	var lid := _lathe([
		Vector2(0.285,0.88), Vector2(0.311,0.885), Vector2(0.315,0.905),
		Vector2(0.315,0.925), Vector2(0.301,0.94), Vector2(0.278,0.94),
		Vector2(0.273,0.93), Vector2(0.0,0.93)], black)
	for row in range(2):
		for column in range(2):
			var barrel := StaticBody3D.new()
			barrel.name = "Barrel_%d_%d" % [row+1,column+1]
			barrel.position = Vector3(wall_start_x-0.34-row*SPACING,0,108.0+(column-0.5)*SPACING)
			add_child(barrel)
			for mesh in [body,lid]:
				var visual := MeshInstance3D.new()
				visual.mesh = mesh
				barrel.add_child(visual)
			var shape := CylinderShape3D.new()
			shape.radius = 0.315
			shape.height = HEIGHT
			var collision := CollisionShape3D.new()
			collision.shape = shape
			collision.position.y = HEIGHT/2
			barrel.add_child(collision)
			# Recessed fill plug in the black lid.
			var plug := MeshInstance3D.new()
			var plug_mesh := CylinderMesh.new()
			plug_mesh.top_radius = 0.038
			plug_mesh.bottom_radius = 0.038
			plug_mesh.height = 0.009
			plug_mesh.radial_segments = 16
			plug_mesh.material = black
			plug.mesh = plug_mesh
			plug.position = Vector3(0.16,0.934,0.04)
			barrel.add_child(plug)

func _lathe(profile: Array, material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for band in range(profile.size()-1):
		for segment in range(48):
			var a := float(segment)*TAU/48.0
			var b := float(segment+1)*TAU/48.0
			var low: Vector2 = profile[band]
			var high: Vector2 = profile[band+1]
			var points := [Vector3(cos(a)*low.x,low.y,sin(a)*low.x),Vector3(cos(b)*low.x,low.y,sin(b)*low.x),Vector3(cos(b)*high.x,high.y,sin(b)*high.x),Vector3(cos(a)*high.x,high.y,sin(a)*high.x)]
			for index in [0,1,2,0,2,3]:
				surface.add_vertex(points[index])
	surface.generate_normals()
	return surface.commit()
