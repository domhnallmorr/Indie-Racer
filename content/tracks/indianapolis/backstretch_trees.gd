@tool
extends "res://content/tracks/mile_oval/trees/trees.gd"
## Golf-course planting outside the backstretch, using the shared tree meshes.
## Avoid the Turn 2 suites and the Northeast Vista at either end.
var road: Array = []

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/indianapolis/geometry.json"))
	for strip in data.strips:
		if strip.name == "RacingSurface":
			road = strip.rows
	var rng := RandomNumberGenerator.new()
	rng.seed = 5001930
	var groups: Array = []
	for i in range(10): groups.append([])
	for site in range(45):
		var s := lerpf(1420,2200,float(site)/44)+rng.randf_range(-4,4)
		var count := 2 if site%7 == 3 else 1
		for member in range(count):
			var distance := s+member*7.5
			var setback := rng.randf_range(27,33)+member*6
			var variant := (site+member*3)%10
			var scale_factor := rng.randf_range(.9,1.2)
			var transform := Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*scale_factor),_position(distance,setback))
			groups[variant].append(transform)
			placements.append(transform)
	for i in range(10):
		var batch := MultiMeshInstance3D.new()
		batch.name = TREE_NAMES[i]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = make_tree(i)
		multi.instance_count = groups[i].size()
		for j in range(multi.instance_count):
			multi.set_instance_transform(j,groups[i][j])
		batch.multimesh = multi
		add_child(batch)

func _position(s: float, setback: float) -> Vector3:
	var at := fposmod(s,4023.36)/4023.36*(road.size()-1)
	var index := int(at)
	var outer := _v(road[index][0]).lerp(_v(road[index+1][0]),at-index)
	var inner := _v(road[index][-1]).lerp(_v(road[index+1][-1]),at-index)
	var outward := outer-inner
	outward.y = 0
	# Outer wall is 0.5 m thick beyond the racing surface edge.
	var point := outer+outward.normalized()*(setback+.5)
	point.y = -.19
	return point

func _v(p: Array) -> Vector3:
	return Vector3(p[0],p[1],p[2])
