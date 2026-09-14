extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func validate() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_file = "res://content/rosters/default/manifest.json"
	root.add_child(main)
	var fast = main.ai_cars[0]
	var slow = main.ai_cars[1]
	var driver = fast.get_node("Driver")
	var craft = driver.racecraft
	var fixture = load("res://tools/validate_racecraft.gd").new()
	fixture.place(fast,100,0,65)
	fixture.place(slow,160,0,60)
	craft.update(driver,1.0/60)
	check(craft.opponent == slow and craft.target_lane != 0,"Catch should select a passing path")
	# A leader should leave room only when a committed attacker is near enough
	# to reach overlap within one second, not defend a straight ten car lengths
	# in advance.
	var leader = slow.get_node("Driver")
	fixture.place(fast,120,0,70)
	fixture.place(slow,160,0,60)
	driver.racecraft.opponent = slow
	driver.racecraft.target_lane = 1
	leader.racecraft.opponent = null
	leader.racecraft.lane = 0
	leader.racecraft.target_lane = 0
	leader.racecraft.update(leader,1.0/60)
	check(leader.racecraft.target_lane == 0,"Leader must stay on RACE for a distant committed attacker")
	# Closed-loop gaps must preserve front/rear through start/finish.
	craft.own.x = driver.race_length_m-5
	check(absf(craft.gap(driver,5)-10) < .001,"Forward gap wraps across lap seam")
	craft.own.x = 5
	check(absf(craft.gap(driver,driver.race_length_m-5)+10) < .001,"Rear gap wraps across lap seam")
	# Block both destination lanes with nearby traffic, including a fast rear car.
	craft.own = Vector2(100,0)
	craft.nearby.assign([{"car":slow,"gap":8.0,"lateral":-4.0},{"car":main.player,"gap":-8.0,"lateral":4.0}])
	main.player.speed_mps = 70
	check(not craft.lane_clear(driver,-1),"Occupied inside lane must be rejected")
	check(not craft.lane_clear(driver,1),"Fast rear car must block outside lane")
	craft.own.y = -4
	craft.nearby.assign([{"car":slow,"gap":0.0,"lateral":0.0}])
	check(not craft.lane_clear(driver,0),"Return to ideal line must not cross an overlapping car")
	craft.own.y = 0
	craft.nearby.assign([{"car":slow,"gap":15.0,"lateral":4.0}])
	check(craft.traffic_speed(driver,70) < 70,"A nearby car within the high-speed lateral reserve must constrain pace")
	craft.nearby.clear()
	craft.own.y = 8.0
	check(craft.traffic_speed(driver,70) < fast.speed_mps and driver.traffic_reason == "road_edge","Tracking error near road edge must reduce speed")
	# A stalled attempt times out without immediately trying the other side.
	fixture.place(fast,100,0,60)
	fixture.place(slow,160,0,60)
	craft.opponent = slow
	craft.target_lane = -1
	craft.lane = -1
	craft.committed_s = 13
	craft.update(driver,1.0/60)
	check(craft.opponent == null and craft.aborted == 1 and craft.cooldown_s > 0,"Unproductive pass must abort with a cooldown")
	# Verify paths meet the seam and remain in their authored car-centre bounds.
	for side in [-1.0,0.0,1.0]:
		for i in range(driver.race.size()):
			driver.index = i
			var point: Vector3 = craft.path_point(driver,0,side)
			var nearest: Vector3 = Geometry3D.get_closest_point_to_segment(point,craft.inner[i],craft.outer[i])
			check(nearest.distance_to(point) < .02,"Passing path left authored corridor")
		driver.index = 0
		check(craft.path_point(driver,0,side).distance_to(craft.path_point(driver,driver.race_length_m,side)) < .001,"Passing path must wrap seamlessly")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/mile_oval/ai/racing_corridor.json"))
	data.reference_points[0][0] += 1
	var stale = preload("res://game/ai/racecraft.gd").new()
	stale.configure(data,driver.race)
	check(not stale.enabled,"Edited race line must reject stale passing paths")
	fixture.free()
	main.free()
	for failure in failures:
		push_error(failure)
	print("RACECRAFT RULES PASSED" if failures.is_empty() else "RACECRAFT RULES FAILED")
	quit(0 if failures.is_empty() else 1)
