extends SceneTree
var failures: Array[String] = []
const DT := 1.0/60.0

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func reset_craft(car) -> void:
	var driver = car.get_node("Driver")
	var craft = driver.racecraft
	craft.opponent = null
	craft.lane = 0.0
	craft.target_lane = 0.0
	craft.cooldown_s = 0.0
	craft.lane_change_blocked = false
	craft.launch_weight = 0.0
	driver.desired_speed_kph = 95.0*3.6

func validate() -> void:
	root.set_meta("roster_selection",{"track_id":"texas","file":"res://content/rosters/irl_2001/manifest.json","seed":42})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.player.driving_enabled = false
	for car in main.ai_cars:
		car.get_node("Driver").set_physics_process(false)
	var fixture = load("res://tools/validate_racecraft.gd").new()
	var leader = main.get_node("AI_Hornish")
	var follower = main.get_node("AI_Lazier")
	var trailer = main.get_node("AI_Boat")
	var group: Array[Node3D] = [leader,follower,trailer]
	for car in group:
		car.get_node("Driver").rivals.assign(group)
		car.player_state.request_departure()
	fixture.place(leader,118,0,90)
	fixture.place(follower,109,0,90)
	fixture.place(trailer,100,0,90)
	var driver = follower.get_node("Driver")
	var craft = driver.racecraft
	reset_craft(follower)
	driver.desired_speed_kph = 90*3.6
	craft.update(driver,DT)
	check(craft.opponent == null,"Equal available pace should stay in tow")
	driver.desired_speed_kph = 95*3.6
	craft.update(driver,DT)
	print("CLOSE FOLLOW state=",craft.state," target=",craft.target_lane," blocked=",craft.lane_change_blocked)
	check(craft.opponent == leader and craft.target_lane != 0 and not craft.lane_change_blocked,"Faster follower must leave a close three-car queue when a lane is clear")
	var selected: float = craft.target_lane
	# The selected leader must not trap an already-started move at close range.
	reset_craft(follower)
	craft.opponent = leader
	craft.target_lane = selected
	craft.update(driver,DT)
	check(not craft.lane_change_blocked and absf(craft.lane) > 0,"Safe close pull-out can continue after commitment")
	var start_lateral: float = craft.own.y
	var end_lateral: float = craft.lane_lateral(driver,selected,0)
	craft.nearby.assign([{"car":leader,"gap":9.0,"lateral":start_lateral}])
	for progress in [0.0,.3,.6,.9]:
		craft.lane = selected*progress
		craft.own.y = lerpf(start_lateral,end_lateral,progress)
		check(craft.lane_clear(driver,selected,leader),"Safe pull-out remains clear through its whole blend: "+str(progress))
	# A large closing speed consumes the longitudinal room before lateral clearance.
	reset_craft(follower)
	follower.speed_mps = 110
	leader.speed_mps = 80
	craft.update(driver,DT)
	check(craft.opponent == null and craft.target_lane == 0,"Fast closure at short range must brake before pulling out")
	follower.speed_mps = 90
	leader.speed_mps = 90
	reset_craft(follower)
	craft.own = craft.coordinates(driver,follower)
	var origin: float = craft.own.y
	var outside: float = craft.lane_lateral(driver,1,0)
	craft.nearby.assign([{"car":leader,"gap":9.0,"lateral":origin},{"car":trailer,"gap":1.0,"lateral":outside}])
	check(not craft.lane_clear(driver,1,leader),"Occupied destination still blocks a close pull-out")
	craft.nearby.assign([{"car":leader,"gap":9.0,"lateral":lerpf(origin,outside,.5)}])
	check(not craft.lane_clear(driver,1,leader),"Leader crossing the swept path still blocks")
	craft.nearby.assign([{"car":leader,"gap":4.0,"lateral":origin}])
	check(not craft.lane_clear(driver,1,leader),"Bumper overlap still blocks")
	craft.nearby.assign([{"car":leader,"gap":9.0,"lateral":origin}])
	leader.get_node("Driver").racecraft.target_lane = 1
	check(not craft.lane_clear(driver,1,leader),"Leader committing to the same destination has priority")
	leader.get_node("Driver").racecraft.target_lane = 0
	craft.nearby.assign([{"car":leader,"gap":9.0,"lateral":origin},{"car":trailer,"gap":-12.0,"lateral":outside}])
	trailer.speed_mps = 105
	check(not craft.lane_clear(driver,1,leader),"Fast rear car in destination lane still blocks")
	if "--live" in OS.get_cmdline_user_args():
		for i in range(group.size()):
			var car = group[i]
			reset_craft(car)
			fixture.place(car,118.0-i*9.0,0,90)
			var d = car.get_node("Driver")
			d.practice_cycle = false
			d.race_pit_cycle = false
			d.pace_scale = .96 if i == 0 else 1.0
			d.racecraft.attempts = 0
			d.racecraft.passes = 0
			d.set_physics_process(true)
		var contacts := 0
		var max_offset := 0.0
		var moved := false
		for tick in range(2400):
			await physics_frame
			for car in group:
				var d = car.get_node("Driver")
				max_offset = maxf(max_offset,absf(d.racecraft.coordinates(d,car).y))
				if car.car_contact_this_step:
					contacts += 1
				if car != leader and absf(d.racecraft.lane) > .8:
					moved = true
			if tick%600 == 599:
				print("QUEUE LIVE seconds=",(tick+1)/60.0," state=",craft.state," lane=",craft.lane," attempts=",craft.attempts," passes=",craft.passes," contacts=",contacts," offset=",max_offset)
		check(moved and craft.attempts > 0,"Live follower must move out of the queue")
		check(craft.passes+trailer.get_node("Driver").racecraft.passes > 0,"Live faster queue must complete a pass")
		check(contacts == 0 and max_offset < 9.0,"Live queue escape must preserve contact and road clearance")
	fixture.free()
	main.free()
	for failure in failures:
		push_error(failure)
	print("CLOSE FOLLOWING PASSED" if failures.is_empty() else "CLOSE FOLLOWING FAILED")
	quit(0 if failures.is_empty() else 1)
