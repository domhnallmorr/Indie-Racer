extends SceneTree
## Regressions for the Texas edge-speed feedback and discontinuous traffic paths.
const DT := 1.0/60.0
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("validate")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
func lateral(driver, point: Vector3, distance: float) -> float:
	var craft = driver.racecraft
	var at: float = fposmod(driver.race_distances[driver.index]+distance,driver.race_length_m)
	var low: Vector3 = driver._sample_path(craft.inner,driver.race_distances,at)
	var high: Vector3 = driver._sample_path(craft.outer,driver.race_distances,at)
	return (point-low).dot(high-low)/(high-low).length_squared()*16.0-8.0
func validate() -> void:
	root.set_meta("roster_selection",{"track_id":"texas","file":"res://content/rosters/icr2_test/manifest.json","seed":42})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	var car = main.ai_cars[0]
	var other = main.ai_cars[1]
	var driver = car.get_node("Driver")
	var craft = driver.racecraft
	driver.mode = 2
	craft.own = Vector2(0,8.1)
	craft.nearby.clear()
	car.speed_mps = 100.0
	var first: float = craft.traffic_speed(driver,105.0)
	for tick in range(300):
		var request: float = craft.traffic_speed(driver,105.0)
		car.speed_mps = move_toward(car.speed_mps,request,18.0*DT)
	check(first < 100 and first > 95,"Small edge overshoot must apply a modest speed reduction")
	check(absf(car.speed_mps-first) < .001,"Sustained edge correction must settle instead of compounding every tick")
	craft.own.y = 9.5
	check(craft.traffic_speed(driver,105.0) <= 35.0,"A genuine road departure must retain strong recovery braking")
	craft.own.y = 7.5
	check(is_equal_approx(craft.traffic_speed(driver,105.0),105.0),"Clear-track pace must recover after returning inside")
	craft.own.y = -4
	var original: Vector3 = craft.track_lane_point(driver,20,5)
	craft.nearby.assign([{"car":other,"gap":8.99,"lateral":0.0}])
	var before: Vector3 = craft._leave_side_room(driver,20,original)
	check(lateral(driver,before,20) <= -3.19,"Full side clearance must remain inside the overlap guard")
	craft.nearby[0].gap = 9.01
	var after: Vector3 = craft._leave_side_room(driver,20,original)
	check(before.distance_to(after) < .01,"Crossing the 9 m gap must not move the steering target abruptly")
	var previous := after
	for i in range(1,901):
		craft.nearby[0].gap = 9.0+i*.01
		var point: Vector3 = craft._leave_side_room(driver,20,original)
		check(point.distance_to(previous) < .05,"Side-room release must remain continuous through 18 m")
		previous = point
	check(previous.distance_to(original) < .001,"Side-room restriction must release completely when clear")
	craft.nearby[0].gap = 12.0
	craft.own.y = -.99
	before = craft._leave_side_room(driver,20,original)
	craft.own.y = -1.01
	after = craft._leave_side_room(driver,20,original)
	check(before.distance_to(after) < .2,"Crossing 1 m lateral separation must not snap side-room protection")
	craft.nearby.clear()
	craft.lane = .4
	craft.target_lane = 1.0
	craft.lane_change_blocked = false
	before = craft.ahead(driver,22)
	craft.lane_change_blocked = true
	after = craft.ahead(driver,22)
	check(before.distance_to(after) < .001,"Pausing a move must preserve its current steering path")
	craft.target_lane = 0.0
	check(craft.ahead(driver,22).distance_to(after) < .001,"Changing a tactical destination must not snap the committed path")
	var fixture = load("res://tools/validate_racecraft.gd").new()
	fixture.place(car,130,0,65)
	fixture.place(other,138,.5,65)
	driver.rivals.assign([other])
	craft.opponent = other
	craft.target_lane = 1
	craft.update(driver,DT)
	check(craft.lane_change_blocked,"An occupied corridor must block immediately")
	fixture.place(other,180,0,65)
	for tick in range(10):
		craft.update(driver,DT)
	check(craft.lane_change_blocked and craft.lane == 0,"Brief clearance must not restart a paused lane change")
	for tick in range(20):
		craft.update(driver,DT)
	check(not craft.lane_change_blocked and craft.lane > 0,"Sustained clearance must resume the existing move")
	fixture.free()
	main.free()
	for failure in failures:
		push_error(failure)
	print("AI SMOOTHNESS PASSED" if failures.is_empty() else "AI SMOOTHNESS FAILED")
	quit(0 if failures.is_empty() else 1)
