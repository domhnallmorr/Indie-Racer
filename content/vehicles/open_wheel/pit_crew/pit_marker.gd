extends Node3D
## Static crew member with shaped suit panels and human proportions.
const SUIT := Color("9f3035")
const SHADOW_RED := Color("76292f")
const DARK := Color("292c30")
const WHITE := Color("d7d4c9")
const METAL := Color("81878a")

func configure(pit_pose: Transform3D, box_id: String) -> void:
	transform = pit_pose*Transform3D(Basis(Vector3.UP,PI),Vector3(-1.7,0,-3.7))
	set_meta("pit_box_id",box_id)

func _ready() -> void:
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	s.set_smooth_group(0)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = .84
	s.set_material(mat)
	# A relaxed, uneven stance. Boots have a separate sole, toe and ankle.
	for side in [-1.0,1.0]:
		var ankle := Vector3(side*.145,.17,.015 if side < 0 else -.035)
		var knee := Vector3(side*.12,.56,-.015 if side < 0 else -.055)
		var hip := Vector3(side*.095,.94,.015)
		_ellipsoid(s,ankle+Vector3(0,-.125,-.055),Vector3(.093,.037,.16),DARK)
		_ellipsoid(s,ankle+Vector3(0,-.088,-.045),Vector3(.086,.065,.145),Color("383a3c"))
		_ellipsoid(s,ankle+Vector3(0,-.015,.012),Vector3(.079,.115,.086),DARK)
		_sleeve(s,ankle,knee,[.072,.086,.092,.091,.080],[.072,.075,.082,.088,.085],SUIT,side*2)
		_sleeve(s,knee,hip,[.08,.098,.111,.116,.108],[.085,.099,.11,.115,.105],SUIT,side*3)
		_ellipsoid(s,knee,Vector3(.084,.072,.088),SUIT)
		# Shallow creases at the knee and hem, not rigid kneepads.
		_ellipsoid(s,knee+Vector3(0,-.018,-.077),Vector3(.072,.021,.022),SHADOW_RED)
		_ellipsoid(s,ankle+Vector3(0,.065,-.055),Vector3(.064,.012,.028),SHADOW_RED)
	# Continuous shaped waist/chest/shoulder silhouette rather than stacked boxes.
	_loft(s,[Vector3(0,.85,.018),Vector3(0,.93,.012),Vector3(0,1.025,.005),Vector3(0,1.105,0),Vector3(0,1.23,0),Vector3(-.008,1.36,.005),Vector3(-.015,1.44,.01),Vector3(-.015,1.485,.012),Vector3(-.015,1.515,.015)],
		[Vector2(.135,.093),Vector2(.185,.12),Vector2(.164,.11),Vector2(.157,.104),Vector2(.185,.125),Vector2(.212,.133),Vector2(.223,.122),Vector2(.184,.099),Vector2(.075,.071)],SUIT,24,2.0)
	# Fabric belt, collar and a fine zipper tracing the curved front panel.
	_loft(s,[Vector3(0,1.025,.005),Vector3(0,1.065,.003)],[Vector2(.165,.112),Vector2(.161,.111)],SHADOW_RED,24)
	_sleeve(s,Vector3(-.015,1.48,.015),Vector3(-.015,1.555,.015),[.071,.073,.070],[.073,.074,.069],DARK)
	_seam(s,[Vector3(0,1.075,-.108),Vector3(0,1.22,-.128),Vector3(-.008,1.36,-.13),Vector3(-.015,1.465,-.094)],.004,METAL)
	for side in [-1.0,1.0]:
		_seam(s,[Vector3(side*.13,1.11,-.065),Vector3(side*.16,1.26,-.077),Vector3(side*.18,1.38,-.085)],.003,SHADOW_RED)
		_ellipsoid(s,Vector3(side*.11,1.37,-.116),Vector3(.046,.019,.009),WHITE)
	# Raised arm: shoulder follows the pose, elbow bends and wrist narrows.
	var shoulder := Vector3(-.215,1.445,.012)
	var elbow := Vector3(-.36,1.69,.008)
	var wrist := Vector3(-.405,1.945,-.035)
	_ellipsoid(s,shoulder,Vector3(.084,.096,.093),SUIT)
	_sleeve(s,shoulder,elbow,[.082,.086,.076,.067],[.088,.088,.073,.065],SUIT,3)
	_ellipsoid(s,elbow,Vector3(.068,.069,.067),SUIT)
	_sleeve(s,elbow,wrist,[.066,.068,.057,.044],[.065,.064,.05,.043],SUIT,4)
	_sleeve(s,wrist-Vector3(0,.05,0),wrist,[.049,.047],[.044,.043],WHITE)
	_hand(s,Transform3D(Basis(Vector3.BACK,-.10),wrist+Vector3(0,.045,0)),true)
	# The free hand hangs naturally with slightly curled fingers.
	var other_shoulder := Vector3(.21,1.425,.008)
	var other_elbow := Vector3(.275,1.175,.015)
	var other_wrist := Vector3(.26,.98,-.07)
	_ellipsoid(s,other_shoulder,Vector3(.081,.088,.089),SUIT)
	_sleeve(s,other_shoulder,other_elbow,[.081,.079,.067,.060],[.085,.083,.069,.060],SUIT,5)
	_ellipsoid(s,other_elbow,Vector3(.061,.061,.06),SUIT)
	_sleeve(s,other_elbow,other_wrist,[.06,.064,.051,.041],[.06,.06,.049,.04],SUIT,6)
	_sleeve(s,other_wrist,other_wrist+Vector3(0,.035,.015),[.043,.047],[.043,.045],WHITE)
	_hand(s,Transform3D(Basis(Vector3.BACK,PI),other_wrist+Vector3(0,-.047,0)),false)
	# Properly curved full-face helmet shell, visor and chin guard.
	var head := Vector3(-.018,1.675,.005)
	_ellipsoid(s,head,Vector3(.119,.148,.137),WHITE,32)
	_ellipsoid(s,head+Vector3(0,-.095,-.045),Vector3(.104,.048,.106),WHITE)
	_visor(s,head,Vector3(.121,.151,.141),DARK,-.34,.33)
	_visor(s,head,Vector3(.123,.152,.144),Color("253b43"),-.26,.26)
	# Rubber helmet rim and small visor pivots.
	for side in [-1.0,1.0]:
		_ellipsoid(s,head+Vector3(side*.114,.008,-.031),Vector3(.012,.025,.025),DARK)
		_ellipsoid(s,head+Vector3(side*.124,.008,-.031),Vector3(.004,.008,.008),METAL)
		_ellipsoid(s,head+Vector3(side*.063,-.087,-.127),Vector3(.027,.008,.006),DARK)
	# Radio clipped to belt and a discreet curled lead up the suit.
	_ellipsoid(s,Vector3(.166,1.08,.014),Vector3(.028,.072,.04),DARK)
	_seam(s,[Vector3(.177,1.13,.014),Vector3(.186,1.23,.07),Vector3(.19,1.36,.10),Vector3(.10,1.48,.086),head+Vector3(.105,-.06,.035)],.006,DARK)
	s.index()
	var model := MeshInstance3D.new()
	model.name = "CrewMember"
	model.mesh = s.commit()
	add_child(model)

func _hand(s: SurfaceTool, pose: Transform3D, open: bool) -> void:
	_ellipsoid(s,pose.origin,Vector3(.043,.054,.025),WHITE,20,pose.basis)
	for i in range(4):
		var x := -.031+i*.020
		var length: float = [.068,.085,.079,.061][i]
		var a := pose*Vector3(x,.033,0)
		var b := pose*Vector3(x*1.16,.033+length*.55,-.003)
		var c := pose*Vector3(x*1.3,.033+length,-.008 if open else -.039)
		_sleeve(s,a,b,[.0105,.010],[.011,.010],WHITE)
		_sleeve(s,b,c,[.010,.008],[.010,.008],WHITE)
		_ellipsoid(s,c,Vector3(.008,.010,.008),WHITE,12)
	var thumb_a := pose*Vector3(-.031,-.008,0)
	var thumb_b := pose*Vector3(-.060,.009,-.008)
	var thumb_c := pose*Vector3(-.073,.032,-.016)
	_sleeve(s,thumb_a,thumb_b,[.016,.013],[.016,.013],WHITE)
	_sleeve(s,thumb_b,thumb_c,[.013,.010],[.013,.010],WHITE)
	_ellipsoid(s,thumb_c,Vector3(.010,.011,.010),WHITE,12)

func _sleeve(s: SurfaceTool, a: Vector3, b: Vector3, widths: Array, depths: Array, color: Color, folds: float = 0.0) -> void:
	var axis := (b-a).normalized()
	var right := axis.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < .5:
		right = Vector3.RIGHT
	var basis := Basis(right,axis,right.cross(axis))
	var centers: Array = []
	var radii: Array = []
	for i in range(widths.size()):
		centers.append(Vector3(0,a.distance_to(b)*float(i)/(widths.size()-1),0))
		radii.append(Vector2(widths[i],depths[i]))
	_loft(s,centers,radii,color,20,folds,Transform3D(basis,a))

func _loft(s: SurfaceTool, centers: Array, radii: Array, color: Color, segments: int, folds: float = 0.0, pose: Transform3D = Transform3D.IDENTITY) -> void:
	var points: Array[Vector3] = []
	var normals: Array[Vector3] = []
	for ring in range(centers.size()):
		var before: int = maxi(0,ring-1)
		var after: int = mini(centers.size()-1,ring+1)
		var dy: float = maxf(.001,centers[after].y-centers[before].y)
		var slope: Vector2 = (radii[after]-radii[before])/dy
		for j in range(segments):
			var angle := TAU*j/segments
			var wrinkle := 1.0 + (.017*sin(angle*5+ring*2.7+folds) if folds > 0 else 0.0)
			points.append(pose*(centers[ring]+Vector3(cos(angle)*radii[ring].x*wrinkle,0,sin(angle)*radii[ring].y*wrinkle)))
			var normal := Vector3(cos(angle)/radii[ring].x,-(slope.x*cos(angle)*cos(angle)/radii[ring].x+slope.y*sin(angle)*sin(angle)/radii[ring].y),sin(angle)/radii[ring].y).normalized()
			normals.append(pose.basis*normal)
	for ring in range(centers.size()-1):
		for j in range(segments):
			var a := ring*segments+j
			var b := ring*segments+(j+1)%segments
			for idx in [a,b,a+segments,b,b+segments,a+segments]:
				s.set_color(color.srgb_to_linear())
				s.set_normal(normals[idx])
				s.add_vertex(points[idx])
	# End caps are usually hidden inside adjacent fabric / glove sections.
	for end in [0,centers.size()-1]:
		for j in range(segments):
			var order := [(j+1)%segments,j] if end == 0 else [j,(j+1)%segments]
			for p in [pose*centers[end],points[end*segments+order[0]],points[end*segments+order[1]]]:
				s.set_color(color.srgb_to_linear())
				s.set_normal(pose.basis*(Vector3.DOWN if end == 0 else Vector3.UP))
				s.add_vertex(p)

func _ellipsoid(s: SurfaceTool, pos: Vector3, radii: Vector3, color: Color, segments: int = 24, rotation_basis: Basis = Basis.IDENTITY) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = segments
	sphere.rings = 12
	var arrays := sphere.surface_get_arrays(0)
	for index in arrays[Mesh.ARRAY_INDEX]:
		s.set_color(color.srgb_to_linear())
		s.set_normal((rotation_basis*(arrays[Mesh.ARRAY_NORMAL][index]/radii)).normalized())
		s.add_vertex(pos+rotation_basis*(arrays[Mesh.ARRAY_VERTEX][index]*radii))

func _visor(s: SurfaceTool, center: Vector3, radii: Vector3, color: Color, low: float, high: float) -> void:
	for row in range(4):
		for col in range(24):
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var azimuth := lerpf(-1.12,1.12,(col+corner.x)/24.0)
				var elevation := lerpf(low,high,(row+corner.y)/4.0)
				var normal := Vector3(sin(azimuth)*cos(elevation),sin(elevation),-cos(azimuth)*cos(elevation))
				s.set_color(color.srgb_to_linear())
				s.set_normal((normal/radii).normalized())
				s.add_vertex(center+normal*radii)

func _seam(s: SurfaceTool, points: Array, radius: float, color: Color) -> void:
	for i in range(points.size()-1):
		_sleeve(s,points[i],points[i+1],[radius,radius],[radius,radius],color)
