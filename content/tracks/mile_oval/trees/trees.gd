@tool
extends Node3D
## Ten shared branching trees with alpha-cut leaf sprays; deterministic planting.
const STRAIGHT := (1609.344 - TAU * 125.0) / 2.0
const ARC := PI * 125.0
const TREE_NAMES := ["BroadOak","TallElm","RoundMaple","YoungMaple","SlenderPoplar","SpreadingAsh","SmallOrnamental","UnevenLocust","TallCottonwood","CompactLinden"]
const HEIGHTS := [13.0,17.0,11.0,7.0,18.0,12.0,5.5,10.0,19.0,9.0]
const WIDTHS := [11.0,10.0,9.0,5.0,5.0,12.0,5.5,8.0,11.0,7.0]
const COLORS := [Color("#516438"),Color("#596d3d"),Color("#617444"),Color("#72834b"),Color("#617443"),Color("#69774a"),Color("#7e8952"),Color("#768250"),Color("#576d42"),Color("#697f48")]
var placements: Array[Transform3D] = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 19480914
	var by_variant: Array = []
	for i in range(10):
		by_variant.append([])
	# ~1.2 km from T1 entry, along the back straight, to T4 exit.
	# The extra setback clears the stands, sponsor boards and power lines.
	for site in range(36):
		var s := STRAIGHT + 12.0 + float(site)/35.0*(2.0*ARC+STRAIGHT-24.0)
		s += rng.randf_range(-8.0,8.0)
		var setback := rng.randf_range(49.0,74.0)
		var count := rng.randi_range(2,3) if site%8 == 3 else 1
		for member in range(count):
			var distance := s + member*8.0
			var offset := setback + (rng.randf_range(-4.0,4.0) if member>0 else 0.0)
			var point := _position(distance,offset)
			var variant := (site+member*3)%10
			var scale_factor := rng.randf_range(0.88,1.12)
			var basis := Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(Vector3.ONE*scale_factor)
			var transform := Transform3D(basis,point)
			by_variant[variant].append(transform)
			placements.append(transform)
	for i in range(10):
		var batch := MultiMeshInstance3D.new()
		batch.name = TREE_NAMES[i]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = make_tree(i)
		multi.instance_count = by_variant[i].size()
		for j in range(multi.instance_count):
			multi.set_instance_transform(j,by_variant[i][j])
		batch.multimesh = multi
		add_child(batch)

func _position(s: float, setback: float) -> Vector3:
	var outward: Vector3
	var center: Vector3
	if s < STRAIGHT+ARC:
		var angle := -PI/2.0+(s-STRAIGHT)/125.0
		outward = Vector3(cos(angle),0,-sin(angle))
		center = Vector3(STRAIGHT/2.0,0,0)
	elif s < 2.0*STRAIGHT+ARC:
		outward = Vector3(0,0,-1)
		center = Vector3(STRAIGHT/2.0-(s-STRAIGHT-ARC),0,0)
	else:
		var angle := PI/2.0+(s-2.0*STRAIGHT-ARC)/125.0
		outward = Vector3(cos(angle),0,-sin(angle))
		center = Vector3(-STRAIGHT/2.0,0,0)
	return center+outward*(125.0+setback)+Vector3(0,-0.1,0)

func make_tree(index: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2700+index*173
	var height: float = HEIGHTS[index]
	var width: float = WIDTHS[index]
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color("#665b49")
	bark.roughness = 1.0
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	wood.set_material(bark)
	var fork := Vector3(width*.025,height*.34,-width*.018)
	_branch(wood,Vector3.ZERO,fork,height*.021,height*.013)
	_branch(wood,fork,Vector3(-width*.035,height*.78,width*.025),height*.013,.045)
	for root in range(5):
		var angle := root * TAU / 5.0
		_branch(wood,Vector3(cos(angle)*height*.04,.08,sin(angle)*height*.04),Vector3(0,height*.1,0),.04,height*.015)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var foliage := StandardMaterial3D.new()
	foliage.vertex_color_use_as_albedo = true
	foliage.albedo_texture = preload("res://content/tracks/mile_oval/trees/leaf_spray.svg")
	foliage.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	foliage.alpha_scissor_threshold = .12
	foliage.cull_mode = BaseMaterial3D.CULL_DISABLED
	foliage.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	foliage.roughness = 1.0
	foliage.set_flag(BaseMaterial3D.FLAG_DISABLE_AMBIENT_LIGHT,false)
	leaves.set_material(foliage)
	# Branch fans carry many small sprays, leaving porous, irregular silhouettes.
	for lobe in range(11):
		var angle := float(lobe)*2.39996+rng.randf_range(-0.2,0.2)
		var ring := 0.0 if lobe==10 else rng.randf_range(0.20,0.34)*width
		var center := Vector3(cos(angle)*ring,height*rng.randf_range(0.53,0.76),sin(angle)*ring)
		if lobe==10:
			center.y = height*0.82
		var size := Vector3(width*rng.randf_range(0.23,0.31),height*rng.randf_range(0.18,0.24),width*rng.randf_range(0.22,0.30))
		if index==4:
			center.x *= 0.65
			center.z *= 0.65
		var elbow := fork.lerp(center,.6) + Vector3(0,-height*.06,0)
		_branch(wood,fork,elbow,height*.009,height*.004)
		_branch(wood,elbow,center,height*.004,.018)
		for twig in range(5):
			var tip := center + Vector3(rng.randf_range(-.7,.7),rng.randf_range(-.2,.6),rng.randf_range(-.7,.7))*size
			_branch(wood,elbow,tip,.035,.008)
		var tint := Color.WHITE.lerp(COLORS[index],.22).srgb_to_linear()
		_crown(leaves,center,size,tint,rng)
	var mesh := wood.commit()
	leaves.commit(mesh)
	return mesh

func _branch(surface: SurfaceTool, a: Vector3, b: Vector3, bottom: float, top: float) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.bottom_radius = bottom
	cylinder.top_radius = top
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 7
	var axis := (b-a).normalized()
	var side := Vector3.FORWARD.cross(axis).normalized()
	var basis := Basis(side,axis,side.cross(axis))
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,cylinder.surface_get_arrays(0))
	surface.append_from(mesh,0,Transform3D(basis,(a+b)*0.5))

func _crown(surface: SurfaceTool, center: Vector3, size: Vector3, color: Color, rng: RandomNumberGenerator) -> void:
	for spray in range(100):
		var direction := Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
		var offset := direction * pow(rng.randf(), .3333) * size
		var pos := center + offset
		var basis := Basis.from_euler(Vector3(rng.randf_range(-PI,PI),rng.randf_range(-PI,PI),rng.randf_range(-PI,PI)))
		var scale_factor := rng.randf_range(.85,1.55) * clampf(size.x/2.5,.65,1.2)
		var right := basis.x * scale_factor * .5
		var up := basis.y * scale_factor * .5
		var tone := rng.randf_range(.8,1.13) * lerpf(.8,1.0,clampf(offset.y/size.y*.5+.5,0,1))
		# Crown-oriented normals give soft foliage lighting instead of obvious cards.
		var normal := (direction + Vector3.UP*.5).normalized()
		var corners := [pos-right-up,pos+right-up,pos+right+up,pos-right+up]
		var uvs := [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
		for vertex in [0,2,1,0,3,2]:
			surface.set_color(Color(color.r*tone,color.g*tone,color.b*tone))
			surface.set_normal(normal)
			surface.set_uv(uvs[vertex])
			surface.add_vertex(corners[vertex])

