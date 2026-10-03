extends SceneTree

var failures: Array[String] = []
var calls: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func validate() -> void:
	var player := Node3D.new()
	var left := Node3D.new()
	var right := Node3D.new()
	root.add_child(player)
	root.add_child(left)
	root.add_child(right)
	var spotter = preload("res://game/race/spotter.gd").new()
	spotter.callout.connect(func(message: String, _sides: int): calls.append(message))
	left.position = Vector3(-3, 0, 0)
	right.position = Vector3(3, 0, 20)
	spotter.update(player, [left, right], 0.1)
	check(calls == ["CAR LEFT"], "Left overlap is called immediately")
	spotter.update(player, [left, right], 1.0)
	check(calls.size() == 1, "Persistent overlap does not spam calls")
	right.position.z = 0
	spotter.update(player, [left, right], 0.1)
	check(spotter.occupied_sides == 3, "Cars on both sides trigger three wide")
	left.position.z = 8
	spotter.update(player, [left, right], 0.1)
	check(spotter.occupied_sides == 3, "Clearance is debounced")
	spotter.update(player, [left, right], 0.4)
	check(calls.back() == "CLEAR LEFT — CAR RIGHT", "Remaining occupied side is explicit")
	right.position.z = -8
	spotter.update(player, [left, right], 0.5)
	check(calls.back() == "CLEAR RIGHT", "Passing car produces a clear call")
	spotter.reset()
	player.rotation.y = PI / 2.0
	left.position = player.global_basis * Vector3(-3, 0, 0)
	spotter.update(player, [left], 0.1)
	check(spotter.occupied_sides == 1, "Detection follows player heading")
	left.hide()
	spotter.update(player, [left], 0.5)
	check(spotter.occupied_sides == 0, "Hidden cars are ignored")
	spotter.reset()
	player.rotation = Vector3.ZERO
	left.show()
	left.position = Vector3(0, 0, -4)
	spotter.update(player, [left], 0.5)
	check(spotter.occupied_sides == 0, "Following a car does not trigger a side call")
	left.position = Vector3(-3, 4, 0)
	spotter.update(player, [left], 0.5)
	check(spotter.occupied_sides == 0, "Cars at another elevation are ignored")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("SPOTTER PASSED: overlaps, three wide, clearance delay, heading, visibility and following.")
	quit(0 if failures.is_empty() else 1)
