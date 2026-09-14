@tool
extends Node3D
## Visual catchfence protecting the main stand and the Turn 4 / Turn 1 stands.
const STRAIGHT := (1609.344 - TAU * 125.0) / 2.0
const START := -88.0
const END := STRAIGHT + 198.0

func _ready() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("737c80")
	steel.metallic = 0.55
	steel.roughness = 0.65
	var wire := ShaderMaterial.new()
	wire.shader = preload("res://content/tracks/mile_oval/grandstands/catchfence.gdshader")
	var frame := SurfaceTool.new()
	frame.begin(Mesh.PRIMITIVE_TRIANGLES)
	frame.set_material(steel)
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_material(wire)
	var bays := ceili((END - START) / 4.0)
	for i in range(bays + 1):
		var s := lerpf(START, END, float(i) / bays)
		_beam(frame, _point(s, 0), _point(s, 2.8), 0.065)
		_beam(frame, _point(s, 2.8), _point(s, 4.0), 0.065)
		if i == bays:
			continue
		var next := lerpf(START, END, float(i + 1) / bays)
		for height in [0.12, 2.8, 4.0]:
			_beam(frame, _point(s, height), _point(next, height), 0.025)
		# Subdivide each bay so the mesh follows the curved wall closely.
		for j in range(2):
			var a := lerpf(s, next, j / 2.0)
			var b := lerpf(s, next, (j + 1) / 2.0)
			for band in [Vector2(0, 2.8), Vector2(2.8, 4.0)]:
				var vertices := [_point(a, band.x), _point(b, band.x), _point(a, band.y), _point(b, band.y)]
				var uvs := [Vector2(a, band.x), Vector2(b, band.x), Vector2(a, band.y), Vector2(b, band.y)]
				for idx in [0, 2, 1, 1, 2, 3]:
					mesh.set_uv(uvs[idx])
					mesh.add_vertex(vertices[idx])
	for item in [frame, mesh]:
		item.generate_normals()
		var instance := MeshInstance3D.new()
		instance.name = "Steelwork" if item == frame else "WireMesh"
		instance.mesh = item.commit()
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)

func _point(s: float, height: float) -> Vector3:
	var outward := Vector3(0, 0, 1)
	var center := Vector3(-STRAIGHT / 2.0 + s, 0, 125)
	var bank := 0.0
	if s < 0.0 or s > STRAIGHT:
		var u := -s if s < 0.0 else s - STRAIGHT
		var angle := -PI / 2.0 + (s if s < 0.0 else u) / 125.0
		outward = Vector3(cos(angle), 0, -sin(angle))
		center = Vector3(-STRAIGHT / 2.0 if s < 0.0 else STRAIGHT / 2.0, 0, 0) + outward * 125.0
		# Same banking profile as build_mile_oval.py's outer wall.
		var t := clampf(minf(u, PI * 125.0 - u) / 100.0, 0.0, 1.0)
		bank = deg_to_rad(9.0 * t * t * t * (10.0 - 15.0 * t + 6.0 * t * t))
	var inward := maxf(0.0, height - 2.8) * 0.65
	return center + outward * (10.5 - inward) + Vector3.UP * (20.5 * tan(bank) + 1.15 + height)

func _beam(surface: SurfaceTool, a: Vector3, b: Vector3, radius: float) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.FORWARD).normalized()
	if side.length_squared() < 0.5:
		side = axis.cross(Vector3.RIGHT).normalized()
	var other := axis.cross(side)
	for i in range(6):
		var p := (side * cos(TAU * i / 6.0) + other * sin(TAU * i / 6.0)) * radius
		var q := (side * cos(TAU * (i + 1) / 6.0) + other * sin(TAU * (i + 1) / 6.0)) * radius
		for vertex in [a + p, b + p, a + q, a + q, b + p, b + q]:
			surface.add_vertex(vertex)
