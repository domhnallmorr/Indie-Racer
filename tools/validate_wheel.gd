extends SceneTree
const Wheel = preload("res://game/input/wheel_input.gd")
func _initialize() -> void:
	assert(is_equal_approx(Wheel.normalize_axis(-1, [-1.0, 0.0, 1.0], true), 1))
	assert(is_equal_approx(Wheel.normalize_axis(1, [-1.0, 0.0, 1.0], true), -1))
	assert(is_zero_approx(Wheel.normalize_axis(0.2, [0.9, 0.2, -0.8], true)))
	assert(is_equal_approx(Wheel.normalize_axis(0.9, [0.9, 0.2, -0.8], true), 1))
	assert(is_zero_approx(Wheel.normalize_axis(1, [1.0, -1.0], false)))
	assert(is_equal_approx(Wheel.normalize_axis(-1, [1.0, -1.0], false), 1))
	assert(is_equal_approx(Wheel.normalize_axis(1, [0.0, 1.0], false), 1))
	call_deferred("check_scene")
func check_scene() -> void:
	var scene = load("res://game/main/main.tscn").instantiate()
	scene.ai_enabled = false
	root.add_child(scene)
	await process_frame
	var wheel = scene.get_node("DisplayCar").wheel_input
	wheel.panel.show()
	assert(wheel.controls() == Vector3(0, 1, 0))
	wheel.panel.hide()
	assert(wheel.axis_value("missing") == 0)
	print("WHEEL VALIDATION PASSED: directions, inverted pedals, centre, setup braking, missing binding, scene startup")
	quit()
