extends SceneTree
const Wheel = preload("res://game/input/wheel_input.gd")
class TestWheel extends Wheel:
	func _ready() -> void:
		panel = PanelContainer.new()
		enabled = CheckButton.new()
		add_child(panel)
		add_child(enabled)
		panel.hide()
	func _device(binding: Dictionary) -> int:
		return 0 if binding.get("connected",false) else -1
	func axis_value(control: String) -> float:
		return .4 if control == "steer" and _device(bindings.get(control,{})) >= 0 else 0.0
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
	for action in ["drive_accelerate","drive_brake","drive_left","drive_right"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var fake := TestWheel.new()
	root.add_child(fake)
	fake.enabled.button_pressed = true
	fake.controls()
	assert(not fake.steering_from_wheel,"Enabled checkbox alone does not select direct steering")
	fake.bindings["steer"] = {"positions":[-1.0,0.0,1.0],"connected":true}
	assert(is_equal_approx(fake.controls().z,.4) and fake.steering_from_wheel,"Connected calibrated axis selects direct steering")
	Input.action_press("drive_left")
	assert(fake.controls().z == 1 and not fake.steering_from_wheel,"Keyboard override retains digital steering")
	Input.action_release("drive_left")
	fake.bindings.steer.connected = false
	assert(fake.controls().z == 0 and not fake.steering_from_wheel,"Disconnect releases the wheel and direct steering")
	fake.bindings.steer.connected = true
	fake.enabled.button_pressed = false
	fake.controls()
	assert(not fake.steering_from_wheel,"Disabled calibrated controls use digital steering")
	fake.enabled.button_pressed = true
	fake.panel.show()
	assert(fake.controls() == Vector3(0,1,0) and not fake.steering_from_wheel,"Setup safely clears the input source")
	fake.panel.hide()
	var scene = load("res://game/main/main.tscn").instantiate()
	scene.ai_enabled = false
	root.add_child(scene)
	await process_frame
	var original_wheel = scene.player.wheel_input
	var was_driving: bool = scene.player.driving_enabled
	scene.player.wheel_input = fake
	scene.player.driving_enabled = true
	scene.player._physics_process(1.0/60)
	assert(scene.player.sim.direct_steering,"Player physics routes calibrated wheel input to direct steering")
	fake.enabled.button_pressed = false
	scene.player._physics_process(1.0/60)
	assert(not scene.player.sim.direct_steering,"Player physics clears direct steering on keyboard fallback")
	scene.player.wheel_input = original_wheel
	scene.player.driving_enabled = was_driving
	fake.free()
	var wheel = scene.get_node("DisplayCar").wheel_input
	# The calibration panel is embedded in the Controls page; showing the child
	# alone leaves it hidden under the closed UI shell.
	var race_ui = scene.get_node("HUD/RaceUI")
	race_ui.open_page("controls")
	assert(wheel.controls() == Vector3(0, 1, 0))
	var controls = race_ui.get_node("Shell/Layout/Content/Pages/ControlsPanel")
	var speed_help = controls.find_child("steering_assistance",true,false)
	assert(speed_help != null)
	speed_help.value = 0
	assert(is_equal_approx(scene.player.sim.steering_lock_at_speed(100),28.0),"Controls can select fixed steering mapping")
	speed_help.value = 100
	assert(is_equal_approx(scene.player.sim.steering_lock_at_speed(100),4.5),"Controls can restore speed-only mapping")
	race_ui.close_shell()
	assert(wheel.axis_value("missing") == 0)
	print("WHEEL VALIDATION PASSED: directions, inverted pedals, centre, setup braking, missing binding, scene startup")
	quit()
