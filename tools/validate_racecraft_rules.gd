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
	# Do not pull out while the target is still far down the road.
	fixture.place(fast,100,0,65)
	fixture.place(slow,180,0,60)
	craft.update(driver,1.0/60)
	check(craft.opponent == null and craft.target_lane == 0 and craft.state == "clear","Distant target must not start a pass")
	fixture.place(slow,130,0,65)
	driver.cornering_base = slow.get_node("Driver").cornering_base+.02
	craft.update(driver,1.0/60)
	check(craft.opponent == null and craft.target_lane == 0,"Rating advantage without closing speed must not trigger a move")
	fixture.place(slow,170,0,60)
	craft.update(driver,1.0/60)
	check(craft.opponent == null and craft.target_lane == 0,"Slow catch must wait until closer before pulling out")
	fixture.place(slow,130,0,55)
	craft.update(driver,1.0/60)
	check(craft.opponent == slow and craft.target_lane != 0,"Catch should select a passing path")
	check(craft.state == "closing","Distant pass setup must not be reported as an active pass")
	# Status checks assume the passing lane has been established. An unfinished
	# transition must now hold if the leader enters its swept corridor.
	fixture.place(fast,100,craft.target_lane,65)
	fixture.place(slow,111,0,55)
	craft.update(driver,1.0/60)
	check(craft.state == "closing","Pass status must remain closing beyond ten metres")
	fixture.place(slow,109,0,55)
	craft.update(driver,1.0/60)
	check(craft.state.begins_with("passing_"),"Pass status must begin inside ten metres")
	var tuned = preload("res://game/ai/racecraft.gd").new()
	var corridor: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/mile_oval/ai/racing_corridor.json"))
	tuned.configure(corridor,driver.race,{"passing_status_gap_m":9.0,"lane_blend_distance_m":35.0})
	check(tuned.enabled and is_equal_approx(tuned.passing_status_gap_m,9.0) and is_equal_approx(tuned.lane_blend_distance_m,35.0),"Track racecraft overrides must replace global tuning values")
	fixture.place(slow,230,0,65)
	craft.committed_s = 3
	craft.update(driver,1.0/60)
	check(craft.opponent == null and craft.target_lane == 0,"Distant failed catch must release the passing lane promptly")
	craft.aborted = 0
	# A traffic-limited faster car must still be able to initiate a pass from
	# the following equilibrium, even though both measured speeds are equal.
	fixture.place(fast,100,0,65)
	fixture.place(slow,130,0,65)
	driver.desired_speed_kph = 72*3.6
	craft.cooldown_s = 0
	craft.update(driver,1.0/60)
	check(craft.opponent == slow and craft.target_lane != 0,"Traffic-limited pace advantage must allow escape from a queue")
	driver.desired_speed_kph = 0
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
	# A committed attacker in a clear PASS groove must not make the leader pull
	# to the complementary (often inside) groove.  Holding RACE keeps the leader
	# predictable and requires the attacker to complete the move.
	fixture.place(fast,149,-1,65)
	fixture.place(slow,160,0,60)
	leader.racecraft.target_lane = 0
	leader.racecraft.lane = 0
	leader.racecraft.update(leader,1.0/60)
	check(leader.racecraft.target_lane == 0,"Leader must hold RACE beside a separated passing car")
	# A car ten metres back is not yet a leaving-room concern.  Just inside that
	# window, a committed car that will reach bumper overlap within one second is.
	fixture.place(fast,149,-1,65)
	fixture.place(slow,160,1,60)
	leader.racecraft.update(leader,1.0/60)
	check(leader.racecraft.state not in ["leaving_room","alongside"],"Attacker ten metres back must not hold leaving-room status")
	fixture.place(fast,151,-1,65)
	leader.racecraft.update(leader,1.0/60)
	check(leader.racecraft.state == "leaving_room","Separated cars must not be reported alongside")
	fixture.place(fast,156,-1,65)
	fixture.place(slow,160,1,60)
	leader.racecraft.update(leader,1.0/60)
	check(leader.racecraft.state == "alongside","Bumper-overlapping cars must be reported alongside")
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
	craft.own.y = craft.lane_lateral(driver,0,0)
	craft.nearby.assign([{"car":main.player,"gap":-6.0,"lateral":craft.own.y}])
	check(craft.lane_clear(driver,-1),"Centre-line rear follower must not trap a car on RACE")
	craft.own.y = -4
	craft.nearby.assign([{"car":slow,"gap":0.0,"lateral":0.0}])
	check(not craft.lane_clear(driver,0),"Return to ideal line must not cross an overlapping car")
	craft.own.y = 0
	craft.nearby.assign([{"car":slow,"gap":10.0,"lateral":0.0}])
	slow.speed_mps = 60
	check(craft.traffic_speed(driver,70) < 70 and driver.traffic_reason.begins_with("collision_guard_"),"An imminent same-lane collision must constrain pace")
	craft.begin_green_launch(.3,NAN,0,70)
	check(is_equal_approx(craft.traffic_speed(driver,70),70),"Green launch must not apply collision guarding to the packed formation")
	check(is_equal_approx(craft.target_lane,.3),"Green launch must retain the formation lane before merging")
	craft.green_launch_guard_remaining_s = 0
	craft.green_launch_lane_hold_remaining_s = 0
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
	craft.best_opponent_gap = 60
	craft.no_progress_s = 51
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
