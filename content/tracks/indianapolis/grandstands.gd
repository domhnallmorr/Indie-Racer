@tool
extends Node3D
## Approximate IMS stand groups from the official map, fitted to the imported oval.
## Material-batched scenery only: the racing surface and collision remain separate.
const LAP := 4023.36
const CROWD = preload("res://content/tracks/mile_oval/grandstands/crowd_support_atlas.png")
# Name, start/end distance, rows, canopy, infield side. Unwrapped frontstretch
# intervals cross start/finish; the long east backstretch intentionally stays open.
const STANDS := [
	["Paddock",3680.0,LAP+65.0,38,true,false],
	["A Stand",LAP+80.0,LAP+190.0,36,true,false],
	["B Stand",LAP+205.0,LAP+310.0,36,true,false],
	["E Stand",320.0,475.0,36,true,false],
	["Southwest Vista",490.0,690.0,32,false,false],
	["South Vista",705.0,890.0,32,false,false],
	["G Stand",905.0,995.0,24,false,false],
	# Leave the Turn 2 exit footprint for the VIP suites and a clearance gap.
	["Southeast Vista",1010.0,1220.0,32,false,false],
	["Northeast Vista",2240.0,2700.0,34,false,false],
	["North Vista",2715.0,2895.0,34,false,false],
	["Northwest Vista",2910.0,3270.0,34,false,false],
	["J Stand",3285.0,3385.0,30,false,false],
	["H Stand",3400.0,3490.0,30,false,false],
	["C Stand",3505.0,3665.0,34,false,false],
	["Tower Terrace",3630.0,3820.0,22,false,true],
	["Pit Road Terrace",LAP+70.0,LAP+235.0,18,false,true],
]
var _road: Array = []
var _builders: Dictionary = {}
var _frames: Dictionary = {}
var _materials: Dictionary = {}
var _origin := Vector3.ZERO
var _inside := false
var _container: Node3D

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/indianapolis/geometry.json"))
	for strip in data.strips:
		if strip.name == "RacingSurface":
			_road = strip.rows
	if _road.is_empty():
		return
	for pair in [["Concrete","969b98"],["Benches","c9cfce"],["Steel","566564"],
			["Roof","cbd1ce"],["Fascia","eeeae0"],["Underside","4e5b59"]]:
		_materials[pair[0]] = _material(pair[1])
	var crowd := _material("c5c5c5")
	crowd.albedo_texture = CROWD
	crowd.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials["Spectators"] = crowd
	for stand in STANDS:
		_build_stand(stand)
	_frames.clear()

func _build_stand(spec: Array) -> void:
	var first := float(spec[1])
	var end := float(spec[2])
	var rows := int(spec[3])
	var roofed := bool(spec[4])
	_inside = bool(spec[5])
	_frames.clear()
	_container = Node3D.new()
	_container.name = str(spec[0]).replace(" ","")
	_origin = _point((first+end)*.5,0,0)
	_container.position = _origin
	_container.set_meta("stand_name",spec[0])
	_container.set_meta("rows",rows)
	_container.set_meta("roofed",roofed)
	add_child(_container)
	_builders.clear()
	for key in _materials:
		if not roofed and key in ["Roof","Underside"]:
			continue
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		builder.set_material(_materials[key])
		_builders[key] = builder
	var bays := maxi(1,int(ceil((end-first)/22)))
	var bay_length := (end-first)/bays
	var front := 8.0 if not _inside else 43.0
	var tread := .86
	var rise := .46
	var base := 3.0 if roofed else 1.8
	var rear := front+rows*tread
	var top := base+(rows-1)*rise
	for bay in range(bays):
		var a := first+bay*bay_length
		var b := a+bay_length
		# Treads and risers follow the actual wall, including the curved vistas.
		_ribbon("Concrete",a,b,front,0,front,base-rise)
		for row in range(rows):
			var d := front+row*tread
			var h := base+row*rise
			_ribbon("Concrete",a,b,d,h,d+tread,h)
			_ribbon("Concrete",a,b,d,h-rise,d,h)
			_ribbon("Benches",a+1,b-1,d+.38,h+.30,d+.73,h+.30)
			_ribbon("Spectators",a+1.1,b-1.1,d+.35,h+.33,d+.74,h+.88,true)
			# Half-steps through a 2 m aisle between seating blocks.
			_box("Concrete",a,a+1,d,d+tread*.5,h-rise*.5,h)
		_ribbon("Concrete",a,b,rear,top,rear+2.5,top)
		# Open steel skeleton, diagonal rakers and railings.
		for s in [a+.2,(a+b)*.5]:
			for d in [front+.2,(front+rear)*.5,rear+2.2]:
				var h := minf(top,base+(d-front)/tread*rise)
				_beam(_point(s,d,0),_point(s,d,h),.22)
			_beam(_point(s,front,base-.25),_point(s,rear,top-.25),.22)
			_beam(_point(s,front+2,0),_point(s,rear,top-.25),.14)
			_beam(_point(s,rear+2.2,0),_point(s,front+5,base+3),.14)
			_beam(_point(s,rear+2.4,top),_point(s,rear+2.4,top+1.1),.06)
		for height in [.55,1.1]:
			_ribbon("Steel",a,b,rear+2.4,top+height,rear+2.46,top+height+.05)
		_beam(_point(a+.18,front,base+1),_point(a+.18,rear,top+1),.055)
		for row in range(0,rows,5):
			var d := front+row*tread
			var h := base+row*rise
			_beam(_point(a+.18,d,h),_point(a+.18,d,h+1),.055)
		# Light-coloured cantilever canopy over the upper/penthouse seating.
		if roofed:
			var lip := front+12
			var ceiling := top+5.5
			_ribbon("Roof",a,b,lip,ceiling,rear+4,ceiling+1.5)
			_ribbon("Underside",a,b,lip,ceiling-.22,rear+4,ceiling+1.28)
			_box("Fascia",a,b,lip-.15,lip+.15,ceiling-.7,ceiling+.12)
			_box("Fascia",a,b,rear+3.7,rear+4,ceiling+.6,ceiling+1.5)
			_beam(_point(a+.25,rear+2,0),_point(a+.25,rear+2,ceiling+1.2),.35)
			_beam(_point(a+.25,lip,ceiling-.4),_point(a+.25,rear+2,ceiling+1.2),.25)
			_beam(_point(a+.25,lip+3,ceiling-.3),_point(a+.25,rear+2,top+1),.18)
		# High rear fascia and periodic stair towers break up the long sections.
		_ribbon("Fascia",a,b,rear+2.5,top-.8,rear+2.5,top+.2)
		if bay%4 == 1:
			_box("Concrete",a+2,a+6,rear+2.5,rear+6.5,0,top)
	for s in [first,end]:
		_beam(_point(s,front,base+1),_point(s,rear,top+1),.07)
		for row in range(rows):
			var d := front+row*tread
			var h := base+row*rise
			_quad("Concrete",_point(s,d,h-.46),_point(s,d+tread,h-.46),_point(s,d+tread,h),_point(s,d,h))
	for key in _builders:
		var builder: SurfaceTool = _builders[key]
		builder.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.name = key
		mesh.mesh = builder.commit()
		_container.add_child(mesh)
	var sign := Label3D.new()
	sign.name = "StandName"
	sign.text = str(spec[0]).to_upper()
	sign.font_size = 64
	sign.pixel_size = .018
	sign.outline_size = 0
	sign.modulate = Color("233834")
	var middle := (first+end)*.5
	var sign_d := front+11.75 if roofed else front-.15
	var sign_h := top+5.3 if roofed else base-.65
	sign.position = _point(middle,sign_d,sign_h)-_origin
	_container.add_child(sign)
	var outward := (_point(middle,1,1)-_point(middle,0,1)).normalized()
	sign.look_at(sign.global_position-outward,Vector3.UP,true)
	_builders.clear()

func _point(s: float, distance: float, height: float) -> Vector3:
	if not _frames.has(s):
		var at := fposmod(s,LAP)/LAP*(_road.size()-1)
		var i := int(at)
		var f := at-i
		var outer := _v(_road[i][0]).lerp(_v(_road[i+1][0]),f)
		var inner := _v(_road[i][-1]).lerp(_v(_road[i+1][-1]),f)
		var outward := outer-inner
		outward.y = 0
		_frames[s] = [inner if _inside else outer,(-outward if _inside else outward).normalized()]
	var frame: Array = _frames[s]
	var p: Vector3 = frame[0]+frame[1]*distance
	p.y = -.25 if is_zero_approx(height) else p.y+height
	return p

func _beam(a: Vector3,b: Vector3,width: float) -> void:
	var axis := (b-a).normalized()
	var side := axis.cross(Vector3.FORWARD).normalized()
	if side.length_squared() < .5:
		side = axis.cross(Vector3.RIGHT).normalized()
	var depth := side.cross(axis).normalized()
	var box := BoxMesh.new()
	box.size = Vector3(width,a.distance_to(b),width)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,box.surface_get_arrays(0))
	var builder: SurfaceTool = _builders.Steel
	builder.append_from(mesh,0,Transform3D(Basis(side,axis,depth),(a+b)*.5-_origin))
func _material(hex: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = .9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _v(p: Array) -> Vector3:
	return Vector3(p[0],p[1],p[2])

func _ribbon(key: String,a: float,b: float,d0: float,h0: float,d1: float,h1: float,crowd: bool = false) -> void:
	# Intermediate sections preserve the frontstretch dogleg instead of bridging it.
	var steps := maxi(1,int(ceil((b-a)/6)))
	for i in range(steps):
		var s0 := lerpf(a,b,float(i)/steps)
		var s1 := lerpf(a,b,float(i+1)/steps)
		_quad(key,_point(s0,d0,h0),_point(s0,d1,h1),_point(s1,d1,h1),_point(s1,d0,h0),crowd,(s0-a)/8.0,(s1-a)/8.0)

func _quad(key: String,a: Vector3,b: Vector3,c: Vector3,d: Vector3,crowd: bool = false,u0: float = 0,u1: float = 1) -> void:
	var builder: SurfaceTool = _builders[key]
	var verts := [a,b,c,d]
	var uv := [Vector2(u0,.065),Vector2(u0,.002),Vector2(u1,.002),Vector2(u1,.065)]
	for idx in [0,1,2,0,2,3]:
		builder.set_uv(uv[idx] if crowd else Vector2.ZERO)
		builder.add_vertex(verts[idx]-_origin)

func _box(key: String,a: float,b: float,d0: float,d1: float,h0: float,h1: float) -> void:
	_ribbon(key,a,b,d0,h0,d0,h1)
	_ribbon(key,a,b,d1,h1,d1,h0)
	_ribbon(key,a,b,d0,h1,d1,h1)
	_ribbon(key,a,b,d1,h0,d0,h0)
	for s in [a,b]:
		_quad(key,_point(s,d0,h0),_point(s,d1,h0),_point(s,d1,h1),_point(s,d0,h1))


