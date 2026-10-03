extends SceneTree

class Probe extends "res://game/ai/icr2_driver.gd":
	var speed_calls := 0
	var steering_calls := 0
	var command := 0.01
	func _planned_speed() -> float:
		speed_calls += 1
		return 50.0
	func _pit_entry_speed() -> float:
		return _planned_speed()
	func _sample_steering_curvature(_position: Vector3) -> float:
		steering_calls += 1
		return command

func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	for phase in range(4):
		var driver := Probe.new()
		driver.speed_plan_hz = 15
		driver.steering_plan_hz = 30
		driver.mode = driver.Mode.RACING
		driver.traffic_phase = phase
		driver._update_driving_plan(Vector3.ZERO,1.0/60.0,0)
		assert(driver.driving_curvature == driver.command)
		driver.speed_calls = 0
		driver.steering_calls = 0
		for tick in range(1,121): driver._update_driving_plan(Vector3.ZERO,1.0/60.0,tick)
		assert(driver.speed_calls == 30 and driver.steering_calls == 60)
		driver.command = 0.03
		var refresh_tick := 122+phase%2
		driver._update_driving_plan(Vector3.ZERO,1.0/60.0,refresh_tick)
		assert(is_equal_approx(driver.driving_curvature,0.02))
		driver._update_driving_plan(Vector3.ZERO,1.0/60.0,refresh_tick+1)
		assert(is_equal_approx(driver.driving_curvature,0.03))
		driver.mode = driver.Mode.PIT_ENTRY
		driver.command = -0.02
		var before := driver.speed_calls
		for tick in range(10):
			driver._update_driving_plan(Vector3.ZERO,1.0/60.0,tick)
			assert(driver.driving_curvature == driver.command)
		assert(driver.speed_calls == before+10)
		driver.mode = driver.Mode.RACING
		driver._update_driving_plan(Vector3.ZERO,1.0/60.0,21)
		before = driver.speed_calls
		driver.car_ghost = not driver.car_ghost
		driver._update_driving_plan(Vector3.ZERO,1.0/60.0,21)
		assert(driver.speed_calls == before+1)
		driver.racecraft = preload("res://game/ai/racecraft.gd").new()
		driver.racecraft.nearby.assign([{"gap":10.0,"lateral":0.0}])
		before = driver.speed_calls
		for tick in range(10): driver._update_driving_plan(Vector3.ZERO,1.0/60.0,tick)
		assert(driver.speed_calls == before+10,"Close traffic must restore full-rate planning")
		driver.racecraft.nearby.clear()
		driver.speed_plan_hz = 60
		driver.steering_plan_hz = 60
		before = driver.speed_calls
		var steering_before := driver.steering_calls
		for tick in range(60): driver._update_driving_plan(Vector3.ZERO,1.0/60.0,tick)
		assert(driver.speed_calls == before+60 and driver.steering_calls == steering_before+60)
		driver.free()
	print("DRIVING PLAN CADENCE PASSED: 15/30 Hz across four phases, interpolation, full-rate pits, immediate mode/ghost refresh, 60 Hz fallback.")
	quit()
