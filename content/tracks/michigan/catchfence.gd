@tool
extends "res://content/tracks/mile_oval/grandstands/catchfence.gd"
## Reuse the Mile Oval steelwork and wire mesh over the entire Michigan outer wall.
const LAP := 3218.688
var _wall: Array = []

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/michigan/geometry.json"))
	for strip in data.strips:
		if strip.name == "OuterWall":
			_wall = strip.rows
	if not _wall.is_empty():
		_build_fence(0.0,LAP,true)

func _point(s: float, height: float) -> Vector3:
	var at := fposmod(s,LAP)/LAP*(_wall.size()-1)
	var i := int(at)
	var blend := at-i
	# OuterWall's top vertices are [2] (track side) and [3] (outside).
	var inner_top := _vertex(_wall[i][2]).lerp(_vertex(_wall[i+1][2]),blend)
	var outer_top := _vertex(_wall[i][3]).lerp(_vertex(_wall[i+1][3]),blend)
	var outward := outer_top-inner_top
	outward.y = 0
	outward = outward.normalized()
	var overhang := maxf(0.0,height-2.8)*.65
	return (inner_top+outer_top)*.5+Vector3.UP*height-outward*overhang

func _vertex(p: Array) -> Vector3:
	return Vector3(p[0],p[1],p[2])

