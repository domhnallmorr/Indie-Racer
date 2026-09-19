@tool
extends Node3D
## Track-facing paint, sampled on the actual two-metre wall facets. No collisions.
const LAP := 1609.344
const STRAIGHT := (LAP - TAU * 125.0) / 2.0
const ARC := PI * 125.0
const WALL_STEP := LAP / 805.0
const PANEL_LENGTH := 14.0
const NAMES := ["Marlboro","Target","FedEx","McDonalds","Sears","Bosch","Goodyear","MillerLite"]
const LOGOS := [preload("res://content/tracks/mile_oval/wall_ads/marlboro.svg"),preload("res://content/tracks/mile_oval/wall_ads/target.svg"),preload("res://content/tracks/mile_oval/hoardings/fedex_1994.svg"),preload("res://content/tracks/mile_oval/hoardings/mcdonalds_1993.svg"),preload("res://content/tracks/mile_oval/hoardings/sears.png"),preload("res://content/tracks/mile_oval/hoardings/bosch.png"),preload("res://content/tracks/mile_oval/hoardings/goodyear_wordmark.png"),preload("res://content/tracks/mile_oval/hoardings/miller_lite.png")]
const REGIONS := [Rect2(0,0,1,1),Rect2(0,0,1,1),Rect2(0,0,1,1),Rect2(0,0,1,1),Rect2(0,0,1,1),Rect2(0,.28,1,.49),Rect2(.008,.267,.985,.468),Rect2(.04,.145,.92,.735)]
const ASPECTS := [4.267,4.267,3.196,1.0,4.167,3.646,3.74,1.25]
var panels: Array[Dictionary] = []
var logo_builders: Array[SurfaceTool] = []
var paint_builders: Array[SurfaceTool] = []

func _ready() -> void:
	for i in range(NAMES.size()):
		var logo := StandardMaterial3D.new()
		logo.albedo_texture = LOGOS[i]
		logo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		logo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		logo.roughness = 1.0
		logo.cull_mode = BaseMaterial3D.CULL_DISABLED
		logo.uv1_scale = Vector3(REGIONS[i].size.x,REGIONS[i].size.y,1)
		logo.uv1_offset = Vector3(REGIONS[i].position.x,REGIONS[i].position.y,0)
		logo_builders.append(_builder(logo))
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color("d2232b") if i == 3 else (Color("204c91") if i == 6 else Color("eeeae0"))
		paint.roughness = 1.0
		paint.cull_mode = BaseMaterial3D.CULL_DISABLED
		paint_builders.append(_builder(paint))
	# Eight panels per outer-wall zone, straddling each requested corner boundary.
	_zone("Turn1Entry",STRAIGHT-40.0,8,false,0)
	_zone("Turn2Exit",STRAIGHT+ARC-72.0,8,false,2)
	_zone("Turn3Entry",2.0*STRAIGHT+ARC-40.0,8,false,4)
	_zone("Turn4Exit",LAP-72.0,8,false,6)
	# PitSeparator starts at s=125. Its racing-facing side borders the main straight.
	_zone("InnerFrontStraight",127.0,20,true,0)
	for i in range(NAMES.size()):
		_finish(NAMES[i]+"_Paint",paint_builders[i])
		_finish(NAMES[i]+"_Logos",logo_builders[i])

func _builder(material: Material) -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	return surface

func _zone(label: String, start: float, count: int, inner: bool, first_brand: int) -> void:
	for i in range(count):
		var brand := (first_brand+i)%NAMES.size()
		var a := start+i*PANEL_LENGTH
		var b := a+PANEL_LENGTH-0.25
		panels.append({"zone":label,"start":a,"end":b,"inner":inner,"brand":NAMES[brand]})
		_strip(paint_builders[brand],a,b,0.06 if inner else 0.09,0.94 if inner else 1.06,inner,0.012)
		for repeat in range(3):
			var middle := a+2.3+float(repeat)*4.55
			var width: float = ASPECTS[brand]*(0.70 if inner else 0.73)
			_strip(logo_builders[brand],middle-width/2,middle+width/2,0.15 if inner else 0.21,0.85 if inner else 0.94,inner,0.021)

func _strip(surface: SurfaceTool, start: float, end: float, low: float, high: float, inner: bool, lift: float) -> void:
	var samples: Array[float] = [start]
	var next := (floorf(start/WALL_STEP)+1)*WALL_STEP
	while next < end:
		samples.append(next)
		next += WALL_STEP
	samples.append(end)
	for i in range(samples.size()-1):
		var a := samples[i]
		var b := samples[i+1]
		var verts: Array[Vector3] = [_on_wall(a,low,inner,lift),_on_wall(a,high,inner,lift),_on_wall(b,low,inner,lift),_on_wall(b,high,inner,lift)]
		# Inner face reads left-to-right along travel; outer face reverses that direction.
		var u := (a-start)/(end-start) if inner else 1.0-(a-start)/(end-start)
		var v := (b-start)/(end-start) if inner else 1.0-(b-start)/(end-start)
		var uv := [Vector2(u,1),Vector2(u,0),Vector2(v,1),Vector2(v,0)]
		var normal := (verts[2]-verts[0]).cross(Vector3.UP).normalized()
		if not inner:
			normal = -normal
		for index in [0,1,2,2,1,3]:
			surface.set_normal(normal)
			surface.set_uv(uv[index])
			surface.add_vertex(verts[index])

func _on_wall(s: float, height: float, inner: bool, lift: float) -> Vector3:
	# The imported wall is faceted: interpolate its endpoints rather than a smooth circle.
	var a := floorf(s/WALL_STEP)*WALL_STEP
	var blend := (s-a)/WALL_STEP
	return _wall_vertex(a,height,inner,lift).lerp(_wall_vertex(a+WALL_STEP,height,inner,lift),blend)

func _wall_vertex(distance: float, height: float, inner: bool, lift: float) -> Vector3:
	var s := fposmod(distance,LAP)
	var outward: Vector3
	var center: Vector3
	var arc_distance := -1.0
	if s < STRAIGHT:
		outward = Vector3(0,0,1)
		center = Vector3(-STRAIGHT/2+s,0,125)
	elif s < STRAIGHT+ARC:
		arc_distance = s-STRAIGHT
		var angle := -PI/2+arc_distance/125
		outward = Vector3(cos(angle),0,-sin(angle))
		center = Vector3(STRAIGHT/2,0,0)+outward*125
	elif s < 2*STRAIGHT+ARC:
		outward = Vector3(0,0,-1)
		center = Vector3(STRAIGHT/2-(s-STRAIGHT-ARC),0,-125)
	else:
		arc_distance = s-2*STRAIGHT-ARC
		var angle := PI/2+arc_distance/125
		outward = Vector3(cos(angle),0,-sin(angle))
		center = Vector3(-STRAIGHT/2,0,0)+outward*125
	var bank := 0.0
	if arc_distance >= 0:
		var t := clampf(minf(arc_distance,ARC-arc_distance)/100.0,0,1)
		bank = deg_to_rad(9*t*t*t*(10-15*t+6*t*t))
	var offset := -16.75 if inner else 10.25
	var normal := outward if inner else -outward
	return center+outward*offset+Vector3.UP*(maxf(0,offset+10)*tan(bank)+height)+normal*lift

func _finish(label: String, surface: SurfaceTool) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	surface.index()
	instance.mesh = surface.commit()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
