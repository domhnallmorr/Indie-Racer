@tool
extends Node3D
## Decorative back-straight embankment, facility boundary and power line.
const LENGTH := (1609.344 - TAU * 125.0) / 2.0
const WALL_Z := -144.0
const POLE_Z := WALL_Z - 2.0
const POLE_HEIGHT := 13.0
const SPANS := 9
# Continue through the 90-degree turn 3 and another 15 m of reference arc.
const TURN3_LENGTH := PI * 125.0 / 2.0 + 15.0

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
		var taper0 := clampf((LENGTH/2.0 - x0)/10.0,0,1)
		var taper1 := clampf((LENGTH/2.0 - x1)/10.0,0,1)
		for j in range(profile.size()-1):
			var a := Vector3(x0,profile[j].y*taper0,profile[j].x)
			var b := Vector3(x1,profile[j].y*taper1,profile[j].x)
			var c := Vector3(x0,profile[j+1].y*taper0,profile[j+1].x)
			var d := Vector3(x1,profile[j+1].y*taper1,profile[j+1].x)
			for v in [a,b,c,b,d,c]:
				turf.add_vertex(v)
	# Share the straight's end profile, tapering only at the new far end.
	for i in range(64):
		var s0 := TURN3_LENGTH * i / 64.0
		var s1 := TURN3_LENGTH * (i + 1) / 64.0
		for j in range(profile.size() - 1):
			var a := _turn_point(s1, -profile[j].x, profile[j].y * clampf((TURN3_LENGTH-s1)/10.0,0,1))
			var b := _turn_point(s0, -profile[j].x, profile[j].y * clampf((TURN3_LENGTH-s0)/10.0,0,1))
			var c := _turn_point(s1, -profile[j+1].x, profile[j+1].y * clampf((TURN3_LENGTH-s1)/10.0,0,1))
			var d := _turn_point(s0, -profile[j+1].x, profile[j+1].y * clampf((TURN3_LENGTH-s0)/10.0,0,1))
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
	_extend_turn3(concrete, timber, porcelain, metal)

func _turn_point(distance: float, radius: float, height: float) -> Vector3:
	var angle := distance / 125.0
	return Vector3(-LENGTH/2.0 - sin(angle)*radius, height, -cos(angle)*radius)

func _extend_turn3(concrete: Material, timber: Material, porcelain: Material, metal: Material) -> void:
	# Short tangent panels follow the curve at the same setback as the straight.
	var bays := ceili(TURN3_LENGTH * (-WALL_Z) / 125.0 / 6.0)
	for i in range(bays):
		var s0 := TURN3_LENGTH * i / bays
		var s1 := TURN3_LENGTH * (i + 1) / bays
		var a := _turn_point(s0, -WALL_Z, 0)
		var b := _turn_point(s1, -WALL_Z, 0)
		var midpoint := (a + b) * .5
		var yaw := (s0 + s1) / 250.0
		_box("Turn3Panel%d" % i, Vector3(a.distance_to(b)-.035,3.2,.35), midpoint+Vector3(0,1.6,0),concrete).rotation.y = yaw
		_box("Turn3Cap%d" % i, Vector3(a.distance_to(b)-.02,.15,.48), midpoint+Vector3(0,3.22,0),concrete).rotation.y = yaw
	# Existing PowerPole0 is the shared junction. Wires span straight between
	# poles (with vertical sag), while crossarms turn radially with the boundary.
	var spans := 6
	for i in range(1, spans + 1):
		var distance := TURN3_LENGTH * i / spans
		var pole := CylinderMesh.new()
		pole.top_radius = .14
		pole.bottom_radius = .24
		pole.height = POLE_HEIGHT
		pole.radial_segments = 8
		var instance := MeshInstance3D.new()
		instance.name = "Turn3PowerPole%d" % i
		instance.mesh = pole
		instance.material_override = timber
		instance.position = _turn_point(distance, -POLE_Z, POLE_HEIGHT/2.0)
		add_child(instance)
		_box("Turn3Crossarm%d" % i, Vector3(.22,.24,3.4),_turn_point(distance,-POLE_Z,12.15),timber).rotation.y = distance/125.0
		for offset in [-1.35,0.0,1.35]:
			_box("Turn3Insulator",Vector3(.2,.4,.2),_turn_point(distance,-POLE_Z+offset,12.45),porcelain)
			var start := _turn_point(TURN3_LENGTH*(i-1)/spans,-POLE_Z+offset,12.65)
			var finish := _turn_point(distance,-POLE_Z+offset,12.65)
			var last := start
			for step in range(1,13):
				var t := step/12.0
				var next := start.lerp(finish,t) - Vector3(0,4.0*t*(1.0-t),0)
				_wire(last,next,metal)
				last = next

func _material(strip: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://content/tracks/mile_oval/backstraight/material.gdshader")
	mat.set_shader_parameter("atlas",preload("res://content/tracks/mile_oval/backstraight/material_atlas.png"))
	mat.set_shader_parameter("strip",strip)
	return mat

func _box(label: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	add_child(instance)
	return instance

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
