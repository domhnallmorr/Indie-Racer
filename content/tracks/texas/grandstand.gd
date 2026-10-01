@tool
extends Node3D
## Photo-inspired frontstretch stand; distances follow the Texas outer wall.
const LAP := 2414.016
const START := 2050.0
const END := LAP + 350.0
const BAYS := 30
const ROWS := 48
const CROWD = preload("res://content/tracks/mile_oval/grandstands/crowd_support_atlas.png")
var _road: Array = []
var _builders: Dictionary = {}
var _frames: Dictionary = {}

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/texas/geometry.json"))
	for strip in data.strips:
		if strip.name == "RacingSurface":
			_road = strip.rows
	if _road.is_empty():
		return
	var concrete := _material("#b5b6af")
	var trim := _material("#e0e3df")
	var steel := _material("#6d787c")
	var dark := _material("#3e484e")
	var glass := _material("#203b49")
	glass.metallic = .35
	glass.roughness = .25
	var crowd := _material("#d0d0d0")
	crowd.albedo_texture = CROWD
	crowd.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var blue := _material("#278cae")
	for pair in [["Concrete",concrete],["WhiteFascias",trim],["Steel",steel],["RearStructure",dark],["SuiteWindows",glass],["Spectators",crowd],["RoofAccents",blue]]:
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		builder.set_material(pair[1])
		_builders[pair[0]] = builder
	var bay_length := (END-START)/BAYS
	for bay in range(BAYS):
		var a := START+bay*bay_length
		var b := a+bay_length
		# Close the underside up to the first riser, following its exact curve.
		_ribbon("Concrete",a,b,8,0,8,5.0-.62)
		# Real stepped seating, separated by broad concrete stair aisles.
		for row in range(ROWS):
			var d := 8.0+row*1.0
			var h := 5.0+row*.62
			_ribbon("Concrete",a,b,d,h,d+1,h)
			_ribbon("Concrete",a,b,d,h-.62,d,h)
			# Crop one spectator row from the shared crowd atlas, above each tread.
			_ribbon("Spectators",a+1.0,b-1.0,d+.20,h+.025,d+.95,h+.49,true)
		# Cross aisle divides the seating bowl into upper and lower sections.
		_ribbon("Concrete",a,b,30,18.7,32,19.94)
		_ribbon("Concrete",a,b,56,34.8,61,34.8)
		# A continuous three-storey suite/press building crowns the full stand.
		_box("RearStructure",a,b,60,76,35,48)
		for floor_index in range(3):
			var h := 36.0+floor_index*4
			_ribbon("SuiteWindows",a,b,59.8,h,59.8,h+3.2)
			_box("WhiteFascias",a,b,59.3,60.3,h-.35,h)
			for pane in range(6):
				var s := a+(b-a)*pane/6.0
				_box("Steel",s,s+.11,59.55,60.0,h,h+3.2)
		_box("WhiteFascias",a,b,58.5,77,48,49)
		_box("WhiteFascias",a,b,58.3,59.0,47.3,49.5)
		# Concrete rear piers, front suite columns, and a closed rear facade.
		_box("Steel",a,a+.45,58.8,59.3,30,36)
		_box("Concrete",a,a+.8,73,74,0,35)
		_ribbon("RearStructure",a,b,75,0,75,35)
		if bay % 5 == 2:
			_box("WhiteFascias",a+6,b-6,64,72,49,51)
			_box("RoofAccents",a+7,b-7,64.5,71.5,51,52)
	# Close both ends to the actual stepped profile, including the rear concourse.
	for s in [START,END]:
		for row in range(ROWS):
			var d := 8.0+row
			var h := 5.0+row*.62
			_quad("Concrete",_point(s,d,0),_point(s,d+1,0),_point(s,d+1,h),_point(s,d,h))
		_quad("Concrete",_point(s,56,0),_point(s,61,0),_point(s,61,34.8),_point(s,56,34.8))
		_quad("RearStructure",_point(s,61,0),_point(s,76,0),_point(s,76,35),_point(s,61,35))
	for key in _builders:
		var builder: SurfaceTool = _builders[key]
		builder.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.name = key
		mesh.mesh = builder.commit()
		add_child(mesh)
	_builders.clear()
	var sign := Label3D.new()
	sign.name = "SpeedwaySign"
	sign.text = "TEXAS MOTOR SPEEDWAY"
	sign.font_size = 96
	sign.pixel_size = .035
	sign.modulate = Color("#182f41")
	sign.outline_size = 0
	sign.position = _point(LAP,58.0,48.2)
	add_child(sign)
	var outward := (_point(LAP,1,0)-_point(LAP,0,0)).normalized()
	sign.look_at(sign.global_position-outward,Vector3.UP,true)

func _material(hex: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = .9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _point(s: float, distance: float, height: float) -> Vector3:
	if not _frames.has(s):
		# Smooth source-section joins so the deep seating bowl cannot fold over
		# itself at the frontstretch dogleg.
		var outer := Vector3.ZERO
		var inner := Vector3.ZERO
		var total := 0.0
		for sample in range(-8,9):
			var weight := float(9-absi(sample))
			var at := fposmod(s+sample*8.0,LAP)/LAP*(_road.size()-1)
			var i := int(at)
			var f := at-i
			outer += _v(_road[i][0]).lerp(_v(_road[i+1][0]),f)*weight
			inner += _v(_road[i][-1]).lerp(_v(_road[i+1][-1]),f)*weight
			total += weight
		outer /= total
		inner /= total
		var outward := outer-inner
		outward.y = 0
		_frames[s] = [outer,outward.normalized()]
	var frame: Array = _frames[s]
	var p: Vector3 = frame[0]+frame[1]*distance
	# Seating and suites follow the outer road's elevation through the banking
	# transitions. Sink foundation feet just below the ground plane at -0.2 m
	# so there is no daylight slit underneath the front or side cladding.
	p.y = -.25 if is_zero_approx(height) else p.y+height
	return p

func _v(p: Array) -> Vector3:
	return Vector3(p[0],p[1],p[2])

func _ribbon(key: String,a: float,b: float,d0: float,h0: float,d1: float,h1: float,crowd: bool = false) -> void:
	# Intermediate sections preserve the frontstretch dogleg instead of bridging it.
	var steps := maxi(1,int(ceil((b-a)/4)))
	for i in range(steps):
		var s0 := lerpf(a,b,float(i)/steps)
		var s1 := lerpf(a,b,float(i+1)/steps)
		_quad(key,_point(s0,d0,h0),_point(s0,d1,h1),_point(s1,d1,h1),_point(s1,d0,h0),crowd,float(i)/steps,float(i+1)/steps)

func _quad(key: String,a: Vector3,b: Vector3,c: Vector3,d: Vector3,crowd: bool = false,u0: float = 0,u1: float = 1) -> void:
	var builder: SurfaceTool = _builders[key]
	var verts := [a,b,c,d]
	var uv := [Vector2(u0,.065),Vector2(u0,.002),Vector2(u1,.002),Vector2(u1,.065)]
	for idx in [0,1,2,0,2,3]:
		builder.set_uv(uv[idx] if crowd else Vector2.ZERO)
		builder.add_vertex(verts[idx])

func _box(key: String,a: float,b: float,d0: float,d1: float,h0: float,h1: float) -> void:
	_ribbon(key,a,b,d0,h0,d0,h1)
	_ribbon(key,a,b,d1,h1,d1,h0)
	_ribbon(key,a,b,d0,h1,d1,h1)
	_ribbon(key,a,b,d1,h0,d0,h0)
	for s in [a,b]:
		_quad(key,_point(s,d0,h0),_point(s,d1,h0),_point(s,d1,h1),_point(s,d0,h1))

