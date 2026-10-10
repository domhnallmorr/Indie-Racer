@tool
extends Node3D
## Authored from the user's tower front/aerial photographs; dimensions are approximate.
## One mesh per material keeps the repeated balconies inexpensive to render.
var specification: Dictionary = {}
var surfaces: Dictionary = {}
var part_transform := Transform3D.IDENTITY

func _ready() -> void:
	var floors := int(specification.get("floors",22))
	var spacing := float(specification.get("floor_height_m",3.2))
	var height := 4.0+floors*spacing
	_wing(floors,spacing,height,true)
	var second: Dictionary = specification.get("second_wing",{"position":[25,0,-24],"heading_deg":90})
	var at: Array = second.position
	part_transform = Transform3D(Basis(Vector3.UP,deg_to_rad(second.heading_deg)),Vector3(at[0],at[1],at[2]))
	_wing(floors,spacing,height,false)
	part_transform = Transform3D.IDENTITY
	_central_facade(height)
	# Retain the tree and lights along the original street-facing frontage.
	_box(Vector3(0,.08,17.7),Vector3(40,.16,15.6),"#b7b9ae")
	_box(Vector3(-1,.28,16.5),Vector3(34,.40,9),"#5c8249")
	_box(Vector3(-1,.65,21.1),Vector3(34,1.1,.48),"#e0e2d9")
	for x in range(-16,17,3):
		_ellipsoid(Vector3(x,1.7,19.4),Vector3(2.3,1.5,1.6),"#3d6337")
	_tree(Vector3(-8,0,18))
	for x in [-18.8,18.8]:
		_street_light(Vector3(x,0,24.8))
	_box(Vector3(35,.08,-23),Vector3(8,.16,38),"#b7b9ae")
	_commit()

func _wing(floors: int,spacing: float,height: float,pergola: bool) -> void:
	var facade := PackedVector2Array()
	for i in range(9):
		var angle := PI-float(i)*PI/16
		facade.append(Vector2(-12+6*cos(angle),4+6*sin(angle)))
	for p in [Vector2(-7,9.6),Vector2(0,8.8),Vector2(7,8.8),Vector2(12,10)]:
		facade.append(p)
	for i in range(1,9):
		var angle := PI/2-float(i)*PI/16
		facade.append(Vector2(12+4*cos(angle),6+4*sin(angle)))
	var footprint := PackedVector2Array([Vector2(-18,-9)])
	footprint.append_array(facade)
	footprint.append(Vector2(16,-9))
	var core := PackedVector2Array()
	for p in footprint: core.append(Vector2(p.x*.93,p.y*.80))
	_extrude(core,0,height,"#e0e4de")
	# Dark recessed glazing behind the projecting balcony edge, broken by mullions.
	for level in range(floors):
		var floor_y := 4.0+level*spacing
		_extrude(footprint,floor_y,.24,"#f2f1e6")
		for i in range(facade.size()-1):
			var a := facade[i]
			var b := facade[i+1]
			var pieces := maxi(1,ceili(a.distance_to(b)/1.9))
			for j in range(pieces):
				var central := a.x>=-12 and b.x<=12
				var inset := .29 if central else .07
				var p := a.lerp(b,(float(j)+inset)/pieces)
				var q := a.lerp(b,(float(j)+1-inset)/pieces)
				var pa := Vector3(p.x*.935,floor_y+.62,p.y*.805)
				var pb := Vector3(q.x*.935,floor_y+.62,q.y*.805)
				_quad(pa,pb,pb+Vector3.UP*1.92,pa+Vector3.UP*1.92,"#83b0ac" if (j+level)%4 else "#547e85")
			# Solid cream balcony fascia and a slender top rail follow the curve.
			var v := Vector3(a.x,floor_y+.24,a.y)
			var w := Vector3(b.x,floor_y+.24,b.y)
			_quad(v,w,w+Vector3.UP*.62,v+Vector3.UP*.62,"#f2f1e6")
			_tube(v+Vector3.UP*.98,w+Vector3.UP*.98,.035,"#e6e9df")
			_tube(v+Vector3.UP*.60,v+Vector3.UP*.98,.026,"#d5ddd7")
	_extrude(footprint,height,.36,"#f2f1e6")
	var deck := PackedVector2Array()
	for p in footprint: deck.append(p*.96)
	_extrude(deck,height+.36,.05,"#cbb393")
	_roof_pool(height+.43,-7 if pergola else 7)
	if pergola:
		for x in [5,12]:
			for z in [-5,4]:
				_box(Vector3(x,height+1.65,z),Vector3(.15,2.4,.15),"#948574")
		for z in range(-5,5):
			_box(Vector3(8.5,height+2.9,z),Vector3(8,.16,.16),"#948574")
		for x in [5,12]:
			_box(Vector3(x,height+2.8,-.5),Vector3(.18,.18,10),"#948574")
	for i in range(footprint.size()):
		var p := footprint[i]
		var q := footprint[(i+1)%footprint.size()]
		_tube(Vector3(p.x,height+1.2,p.y),Vector3(q.x,height+1.2,q.y),.045,"#d5ddd7")
		_tube(Vector3(p.x,height+.36,p.y),Vector3(p.x,height+1.2,p.y),.035,"#d5ddd7")
	_box(Vector3(-1,2,0),Vector3(31,4,15),"#7b9d9a")
	for x in range(-14,16,4):
		_box(Vector3(x,2,7.6),Vector3(.4,4,.5),"#e7e9e1")

func _central_facade(height: float) -> void:
	# A solid diagonal link joins the two perpendicular balcony blocks.
	# Its broad blank face and rounded vertical piers are visible from the corner.
	var core := PackedVector2Array([Vector2(16,7),Vector2(29,-6),Vector2(28,-23),
		Vector2(16,-23),Vector2(9,-12),Vector2(13,-7)])
	_extrude(core,0,height+3,"#e4e7e0")
	var a := Vector3(16,0,7)
	var b := Vector3(29,0,-6)
	var outward := Vector3(1,0,1).normalized()
	var inset_a := a.lerp(b,.055)+outward*.025
	var inset_b := a.lerp(b,.945)+outward*.025
	_quad(inset_a,inset_b,inset_b+Vector3.UP*(height+2.4),inset_a+Vector3.UP*(height+2.4),"#d4dcda")
	for y in range(4,int(height+1),3):
		_quad(inset_a+Vector3.UP*y+outward*.03,inset_b+Vector3.UP*y+outward*.03,
			inset_b+Vector3.UP*(y+.065)+outward*.03,inset_a+Vector3.UP*(y+.065)+outward*.03,"#b6c5c4")
	for p in [a,b]:
		_tube(p,p+Vector3.UP*(height+4),.85,"#f2f1e6")
	# Recessed service roof behind the central face.
	_box(Vector3(20,height+3.3,-13),Vector3(9,.5,9),"#acb4b2")
	for x in [17,22]:
		_box(Vector3(x,height+4.3,-14),Vector3(2.7,1.5,3.8),"#c8cec7")
		_tube(Vector3(x,height+5.05,-14),Vector3(x,height+5.15,-14),.85,"#748482")

func _roof_pool(y: float,centre_x: float) -> void:
	var coping := PackedVector2Array()
	var water := PackedVector2Array()
	for i in range(32):
		var angle := float(i)*TAU/32
		var bend := 1.0-.16*cos(angle*3)
		var p := Vector2(cos(angle)*6*bend,sin(angle)*3.7)
		coping.append(Vector2(centre_x,0)+p*1.13)
		water.append(Vector2(centre_x,0)+p)
	_extrude(coping,y,.12,"#eee8d4")
	_extrude(water,y+.13,.025,"#69b5bd")

func _surface(colour: String) -> SurfaceTool:
	if not surfaces.has(colour):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(colour)
		mat.roughness = .82
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		st.set_material(mat)
		surfaces[colour] = st
	return surfaces[colour]

func _quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,colour: String) -> void:
	var st := _surface(colour)
	for p in [a,c,b,a,d,c]: st.add_vertex(part_transform*p)

func _primitive(mesh: PrimitiveMesh,transform: Transform3D,colour: String) -> void:
	var array := ArrayMesh.new()
	array.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0))
	_surface(colour).append_from(array,0,part_transform*transform)

func _box(at: Vector3,size: Vector3,colour: String) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_primitive(mesh,Transform3D(Basis.IDENTITY,at),colour)

func _tube(a: Vector3,b: Vector3,radius: float,colour: String) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	var direction := (b-a).normalized()
	var basis := Basis(Quaternion(Vector3.UP,direction))
	_primitive(mesh,Transform3D(basis,(a+b)*.5),colour)

func _ellipsoid(at: Vector3,radii: Vector3,colour: String) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 10
	mesh.rings = 5
	_primitive(mesh,Transform3D(Basis.from_scale(radii),at),colour)

func _extrude(outline: PackedVector2Array,y: float,height: float,colour: String) -> void:
	var st := _surface(colour)
	var indices := Geometry2D.triangulate_polygon(outline)
	for i in range(0,indices.size(),3):
		for j in [0,1,2]:
			var p := outline[indices[i+j]]
			st.add_vertex(part_transform*Vector3(p.x,y+height,p.y))
		for j in [2,1,0]:
			var p := outline[indices[i+j]]
			st.add_vertex(part_transform*Vector3(p.x,y,p.y))
	for i in range(outline.size()):
		var p := outline[i]
		var q := outline[(i+1)%outline.size()]
		_quad(Vector3(p.x,y,p.y),Vector3(q.x,y,q.y),Vector3(q.x,y+height,q.y),Vector3(p.x,y+height,p.y),colour)

func _tree(at: Vector3) -> void:
	_tube(at,at+Vector3(.4,7,0),.35,"#6b6651")
	for i in range(7):
		var angle := float(i)*TAU/7
		var tip := at+Vector3(cos(angle)*3,6.3+float(i%3)*.65,sin(angle)*2.6)
		_tube(at+Vector3(0,3.2,0),tip,.15,"#6b6651")
		_ellipsoid(tip,Vector3(3.1,2.6,2.7),"#3a623e" if i%2 else "#527849")
	_ellipsoid(at+Vector3(0,8,0),Vector3(3.5,2.7,3.2),"#476e41")

func _street_light(at: Vector3) -> void:
	# Gooseneck arm bends out over the pavement, with a slim period lamp head.
	_box(at+Vector3(0,.10,0),Vector3(.65,.20,.65),"#b8bcb4")
	var points := [Vector3.ZERO,Vector3(0,7.5,0),Vector3(0,9.1,.18),
		Vector3(0,10,.7),Vector3(0,10.7,1.6),Vector3(0,11.3,3.1),Vector3(0,11.6,4.1)]
	for i in range(points.size()-1):
		_tube(at+points[i],at+points[i+1],.10 if i==0 else .075,"#899b9a")
	_box(at+Vector3(0,11.58,4.2),Vector3(.42,.22,1.05),"#657979")
	_box(at+Vector3(0,11.45,4.2),Vector3(.32,.03,.80),"#eee9ce")

func _commit() -> void:
	for colour in surfaces:
		var st: SurfaceTool = surfaces[colour]
		st.generate_normals()
		var instance := MeshInstance3D.new()
		instance.name = "TowerDetail"
		instance.mesh = st.commit()
		add_child(instance,true)
