extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func run() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_file = "res://content/rosters/icr2_test/manifest.json"
	root.add_child(main)
	var car = main.ai_cars[0]
	var other = main.ai_cars[1]
	var driver = car.get_node("Driver")
	var craft = driver.racecraft
	var fixture = load("res://tools/validate_racecraft.gd").new()
	fixture.place(car,130,0,65)
	fixture.place(other,133,1,65)
	craft.own = craft.coordinates(driver,car)
	craft.nearby.assign([{"car":other,"gap":3.0,"lateral":craft.own.y+4.0}])
	craft._update_stalemate(driver,2.0)
	check(craft.yielding_car == null,"Brief overlap does not cause a yield")
	check(is_equal_approx(craft.traffic_speed(driver,70),70),"Safely separated neighbour does not constrain pace")
	for tick in range(241):
		craft._update_stalemate(driver,1.0/60)
	check(craft.yielding_car == other,"Trailing car resolves persistent overlap")
	check(craft.traffic_speed(driver,70) <= 63.5,"Yield gently reduces speed")
	var other_driver = other.get_node("Driver")
	var other_craft = other_driver.racecraft
	other_craft.own = other_craft.coordinates(other_driver,other)
	other_craft.nearby.assign([{"car":car,"gap":-3.0,"lateral":other_craft.own.y-4.0}])
	for tick in range(361):
		other_craft._update_stalemate(other_driver,1.0/60)
	check(other_craft.yielding_car == null,"Leading car does not yield reciprocally")
	craft._update_stalemate(driver,4.1)
	check(craft.yielding_car == null and craft.yield_cooldown_s > 0,"Yield is bounded and has cooldown")
	# A neighbour no longer pins a car in launch mode indefinitely.
	craft.begin_green_launch(0,craft.own.y,0,65)
	craft.green_launch_lane_hold_remaining_s = 0
	for tick in range(120):
		craft.update(driver,1.0/60)
	check(craft.launch_weight == 0,"Launch ends while neighbour remains alongside")
	# Longitudinal protection remains active for a stopped car in the same lane.
	craft.green_launch_guard_remaining_s = 0
	craft.green_launch_acceleration_remaining_s = 0
	craft.own.y = craft.lane_lateral(driver,0,0)
	craft.nearby.assign([{"car":other,"gap":10.0,"lateral":craft.own.y}])
	other.speed_mps = 0
	check(craft.traffic_speed(driver,70) < 10,"Same-lane stopped traffic remains protected")
	fixture.free()
	main.free()
	for failure in failures:
		push_error(failure)
	print("PACK RELEASE PASSED" if failures.is_empty() else "PACK RELEASE FAILED")
	quit(0 if failures.is_empty() else 1)
