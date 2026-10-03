extends SceneTree

class TrafficClock extends RefCounted:
	var calls := 0
	var seconds := 0.0
	func update(_driver, delta: float) -> void:
		calls += 1
		seconds += delta

class Driver extends "res://game/ai/oval_driver.gd":
	var speed_calls := 0
	func _traffic_speed(request: float) -> float:
		speed_calls += 1
		traffic_reason = "test_guard" if request > 40.0 else "clear"
		return minf(request,40.0)

func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	for hz in [15,30,60]:
		validate_rate(hz)
	print("TRAFFIC CADENCE PASSED: staggered 15/30/60 Hz, elapsed time, cached limits and immediate mode/ghost refresh.")
	quit()

func validate_rate(hz: int) -> void:
	var interval := 60/hz
	var drivers: Array = []
	for phase in range(interval):
		var driver := Driver.new()
		driver.traffic_update_hz = hz
		driver.racecraft = TrafficClock.new()
		driver.mode = driver.Mode.RACING
		driver.traffic_phase = phase
		drivers.append(driver)
	for tick in range(120+interval):
		var refreshes := 0
		for driver in drivers:
			driver._advance_traffic(1.0/60.0,tick+1)
			if driver.traffic_refresh:
				refreshes += 1
			assert(driver._scheduled_traffic_speed(100.0) == 40.0)
		if tick >= interval:
			assert(refreshes == 1,"Opposite phases must spread work across ticks")
	for driver in drivers:
		assert(driver.speed_calls in [hz*2+1,hz*2+2])
		assert(driver.racecraft.calls == driver.speed_calls)
		assert(is_equal_approx(driver.racecraft.seconds+driver.traffic_elapsed,(120.0+interval)/60.0),"Timers must preserve real elapsed time")
		driver.traffic_refresh = false
		assert(driver._scheduled_traffic_speed(20.0) == 20.0,"Cached traffic must not override a lower current speed plan")
		assert(driver.traffic_reason == "clear")
		driver.mode = driver.Mode.PIT_EXIT
		driver._advance_traffic(1.0/60.0)
		assert(driver.traffic_refresh,"Mode changes require immediate refresh")
		driver._scheduled_traffic_speed(100)
		driver.car_ghost = true
		driver._advance_traffic(1.0/60.0)
		assert(driver.traffic_refresh,"Ghost changes require immediate refresh")
		driver.traffic_update_hz = 60
		var before: int = driver.racecraft.calls
		for tick in range(60):
			driver._advance_traffic(1.0/60.0)
			driver._scheduled_traffic_speed(100)
		assert(driver.racecraft.calls-before == 60,"60 Hz comparison mode must update every tick")
		driver.free()
