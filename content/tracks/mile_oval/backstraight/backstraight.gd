@tool
extends Node3D
## Decorative back-straight embankment, facility boundary and power line.
const LENGTH := (1609.344 - TAU * 125.0) / 2.0
const WALL_Z := -144.0
const POLE_Z := WALL_Z - 2.0
const POLE_HEIGHT := 13.0
const SPANS := 9

func _ready() -> void:
	var grass := _material(0.0)
	var concrete := _material(1.0)
	var timber := _material(2.0)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("343b3d")
	metal.roughness = 1.0
	var porcelain := StandardMaterial3D.new()
	porcelain.albedo_color = Color("97aaa5")
	var turf := SurfaceTool.new()
	turf.begin(Mesh.PRIMITIVE_TRIANGLES)
	turf.set_material(grass)
	# Wall's outer face is at z=-135.75; turf starts two metres beyond it.
	var profile := [Vector2(-137.75,0), Vector2(-139.75,2), Vector2(-140.75,2), Vector2(-142.75,0)]
	var segments := 104
	for i in range(segments):
		var x0 := -LENGTH / 2.0 + LENGTH * i / segments
		var x1 := -LENGTH / 2.0 + LENGTH * (i+1) / segments
		var taper0 := clampf((LENGTH/2.0 - absf(x0))/10.0,0,1)
		var taper1 := clampf((LENGTH/2.0 - absf(x1))/10.0,0,1)
		for j in range(profile.size()-1):
			var a := Vector3(x0,profile[j].y*taper0,profile[j].x)
			var b := Vector3(x1,profile[j].y*taper1,profile[j].x)
			var c := Vector3(x0,profile[j+1].y*taper0,profile[j+1].x)
			var d := Vector3(x1,profile[j+1].y*taper1,profile[j+1].x)
			for v in [a,b,c,b,d,c]:
				turf.add_vertex(v)
	turf.generate_normals()
	var bank := MeshInstance3D.new()
	bank.name = "GrassBank"
	bank.mesh = turf.commit()
	add_child(bank)
	var bays := 69
	for i in range(bays):
		var x := -LENGTH/2.0 + LENGTH * (i+.5)/bays
		_box("ConcretePanel%d" % i, Vector3(LENGTH/bays-.035,3.2,.35),Vector3(x,1.6,WALL_Z),concrete)
		_box("ConcreteCap%d" % i, Vector3(LENGTH/bays-.02,.15,.48),Vector3(x,3.22,WALL_Z),concrete)
	for i in range(SPANS+1):
		var x := -LENGTH/2.0 + LENGTH * i / SPANS
		var pole := CylinderMesh.new()
		pole.top_radius = .14
		pole.bottom_radius = .24
		pole.height = POLE_HEIGHT
		pole.radial_segments = 8
		var instance := MeshInstance3D.new()
		instance.name = "PowerPole%d" % i
		instance.mesh = pole
		instance.material_override = timber
		instance.position = Vector3(x,POLE_HEIGHT/2.0,POLE_Z)
		add_child(instance)
		_box("Crossarm%d" % i, Vector3(.22,.24,3.4),Vector3(x,12.15,POLE_Z),timber)
		for z in [-1.35,0.0,1.35]:
			_box("Insulator",Vector3(.2,.4,.2),Vector3(x,12.45,POLE_Z+z),porcelain)
		if i < SPANS:
			for z in [-1.35,0.0,1.35]:
				var last := Vector3(x,12.65,POLE_Z+z)
				for step in range(1,13):
					var t := step/12.0
					var next := Vector3(x+LENGTH/SPANS*t,12.65-4.0*1.0*t*(1.0-t),POLE_Z+z)
					_wire(last,next,metal)
					last = next

func _material(strip: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://content/tracks/mile_oval/backstraight/material.gdshader")
	mat.set_shader_parameter("atlas",preload("res://content/tracks/mile_oval/backstraight/material_atlas.png"))
	mat.set_shader_parameter("strip",strip)
	return mat

func _box(label: String, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	add_child(instance)

func _wire(a: Vector3,b: Vector3,mat: Material) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = .035
	cylinder.bottom_radius = .035
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 4
	var instance := MeshInstance3D.new()
	instance.name = "Cable"
	instance.mesh = cylinder
	instance.material_override = mat
	instance.position = (a+b)/2.0
	var axis := (b-a).normalized()
	var side := Vector3.FORWARD.cross(axis).normalized()
	instance.basis = Basis(side,axis,side.cross(axis))
	add_child(instance)
