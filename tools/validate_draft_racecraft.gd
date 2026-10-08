extends SceneTree
## Indy tow-first approach, safe pull-out and recovery of Daré's stalled attack.
var failures: Array[String] = []
const DT := 1.0/60.0

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func reset(car) -> void:
	var craft = car.get_node("Driver").racecraft
	craft.opponent = null
	craft.draft_leader = null
	craft.cooldown_s = 0.0
	craft.committed_s = 0.0
	craft.no_progress_s = 0.0
	craft.best_opponent_gap = INF
	craft.launch_weight = 0.0
	craft.green_launch_lane_hold_remaining_s = 0.0
	craft.green_launch_guard_remaining_s = 0.0
	craft.lane_change_blocked = false
	craft._reset_corner_commitment()

func validate() -> void:
	root.set_meta("roster_selection",{"track_id":"indianapolis","file":"res://content/rosters/irl_2001/manifest.json","seed":860551894})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.player.driving_enabled = false
	for car in main.ai_cars:
		car.get_node("Driver").set_physics_process(false)
	var follower = main.get_node("AI_Dare")
	var leader = main.get_node("AI_Fisher")
	var neighbour = main.get_node("AI_Boat")
	var driver = follower.get_node("Driver")
	var craft = driver.racecraft
	var fixture = load("res://tools/validate_racecraft.gd").new()
	var group: Array[Node3D] = [follower,leader,neighbour]
	for car in group:
		car.player_state.request_departure()
		car.player_state.is_in_pit_lane = false
		car.player_state.is_in_pit_speed_zone = false
		car.get_node("Driver").rivals.assign(group)
		reset(car)
	# Middle of the front straight, using the real Indy geometry and 90 m blend.
	var straight: float = driver.race_distances[1800]
	fixture.place(neighbour,straight+150,0,95)
	fixture.place(follower,straight,0,95)
	fixture.place(leader,straight+32,0,95)
	driver.desired_speed_kph = 95*3.6
	craft.update(driver,DT)
	check(craft.drafting_follow_max_gap_m == 30 and craft.draft_leader == null and craft.state != "drafting","Do not seek a draft beyond the configured 30 m range")
	reset(follower)
	fixture.place(follower,straight,0,95)
	fixture.place(leader,straight+30,0,94)
	driver.desired_speed_kph = 96*3.6
	craft.update(driver,DT)
	check(craft.opponent == null and craft.draft_leader == leader and craft.target_lane == 0 and craft.state == "drafting","Stay behind a leader 30 m ahead rather than immediately leaving the tow")
	check(craft.traffic_target_name() == "AI_Fisher","Drafting telemetry must identify the leader")
	# A leader on an alternate groove can also provide a tow.
	reset(follower)
	fixture.place(leader,straight+30,1,94)
	craft.update(driver,DT)
	check(craft.opponent == null and craft.draft_leader == leader and craft.target_lane == 1,"Follow the leader's established groove for a tow")
	# The late pull-out uses closing speed and the actual track blend distance.
	reset(follower)
	fixture.place(follower,straight,0,95)
	fixture.place(leader,straight+12,0,94)
	craft.update(driver,DT)
	check(craft.opponent == leader and craft.draft_leader == null and craft.target_lane != 0,"Close enough to pass: pull out with clearance instead of following forever")
	reset(follower)
	fixture.place(follower,straight,0,105)
	fixture.place(leader,straight+25,0,94)
	driver.desired_speed_kph = 105*3.6
	craft.update(driver,DT)
	check(craft.opponent == leader and craft.target_lane != 0,"Rapid closure requires an earlier pull-out")
	# Last-race shape: established inside attempt, 12 m back, almost equal speed.
	reset(follower)
	fixture.place(follower,straight,-1,95)
	fixture.place(leader,straight+12,0,95)
	driver.desired_speed_kph = 95*3.6
	craft.opponent = leader
	craft.committed_s = 20
	craft.best_opponent_gap = 12
	craft.update(driver,DT)
	check(craft.opponent == null and craft.draft_leader == leader and craft.target_lane == 0 and not craft.lane_change_blocked,"A stalled attempt must safely tuck back into Fisher's tow")
	var point: Vector3 = craft.ahead(driver,25)
	check(point.distance_to(craft.path_point(driver,25,craft.lane)) < .01,"Side-room correction must permit a safe nose-to-tail merge")
	# An overlapping neighbour independently blocks the return.
	reset(follower)
	fixture.place(follower,straight,-1,95)
	fixture.place(neighbour,straight+1,0,95)
	craft.opponent = leader
	craft.committed_s = 20
	craft.update(driver,DT)
	check(craft.target_lane == -1 and craft.draft_leader == null,"Do not cross an overlapping neighbour to regain the tow")
	reset(follower)
	fixture.place(follower,straight,-1,95)
	fixture.place(neighbour,straight-12,0,110)
	craft.opponent = leader
	craft.committed_s = 20
	craft.update(driver,DT)
	check(craft.target_lane == -1 and craft.draft_leader == null,"Fast rear traffic must block returning to the tow")
	# An overlap with the passing target takes priority over another tow ahead.
	reset(follower)
	fixture.place(follower,straight,-1,95)
	fixture.place(leader,straight+2,0,95)
	fixture.place(neighbour,straight+40,-1,95)
	craft.opponent = leader
	craft.committed_s = 20
	craft.update(driver,DT)
	check(craft.opponent == leader and craft.draft_leader == null and craft.target_lane == -1,"An established overlap must keep its passing commitment")
	fixture.place(leader,straight+12,0,95)
	fixture.place(neighbour,straight+150,0,95)
	# Projected closure must retain the front reserve during the entire merge.
	craft.own = craft.coordinates(driver,follower)
	craft.nearby.assign([{"car":leader,"gap":12.0,"lateral":craft.lane_lateral(driver,0,0)}])
	follower.speed_mps = 105
	check(not craft.lane_clear(driver,0,null,leader),"Unsafe closure must block tucking behind the leader")
	follower.speed_mps = 95
	craft.nearby.assign([{"car":leader,"gap":4.0,"lateral":craft.lane_lateral(driver,0,0)}])
	check(not craft.lane_clear(driver,0,null,leader),"Bumper overlap must block a tow merge")
	# Corner commitment takes priority over new attacks; disabled tow still
	# retains ordinary pass selection on a straight.
	reset(follower)
	fixture.place(follower,driver.race_distances[250],0,95)
	fixture.place(leader,driver.race_distances[250]+30,0,90)
	driver.desired_speed_kph = 95*3.6
	craft.update(driver,DT)
	check(craft.opponent == null and craft.target_lane == 0 and craft.state == "corner_hold","Hold the entry lane instead of starting a new attack mid-corner")
	reset(follower)
	fixture.place(follower,straight,0,95)
	fixture.place(leader,straight+30,0,94)
	follower.slipstream_enabled = false
	craft.update(driver,DT)
	check(craft.opponent == leader and craft.draft_leader == null,"Tow-disabled cars retain ordinary pass selection")
	follower.slipstream_enabled = true
	if "--live" in OS.get_cmdline_user_args():
		# Start on the T4 exit, then let the real movement/tow/guard run.
		for car in [follower,leader]:
			reset(car)
			car.get_node("Driver").practice_cycle = false
			car.get_node("Driver").race_pit_cycle = false
			car.get_node("Driver").rivals.assign([follower,leader])
		fixture.place(follower,driver.race_distances[1620],0,94)
		fixture.place(leader,driver.race_distances[1620]+30,0,93)
		driver.pace_scale = 1.02
		leader.get_node("Driver").pace_scale = .99
		for car in [follower,leader]:
			car.get_node("Driver").set_physics_process(true)
		var drafting_ticks := 0
		var peak_tow := 0.0
		var contacts := 0
		var edges := 0
		var pull_out_gap := INF
		for tick in range(1200):
			await physics_frame
			if craft.state == "drafting":
				drafting_ticks += 1
			peak_tow = maxf(peak_tow,follower.slipstream_strength)
			if craft.opponent == leader and pull_out_gap == INF:
				pull_out_gap = craft.gap(driver,craft.coordinates(driver,leader).x)
			for car in [follower,leader]:
				if car.car_contact_this_step:
					contacts += 1
				if absf(car.get_node("Driver").racecraft.coordinates(car.get_node("Driver"),car).y) > 9:
					edges += 1
		check(drafting_ticks > 30 and peak_tow > .1,"Live approach must build a tow before attempting a pass")
		check(pull_out_gap < 25,"Live approach must eventually pull out after closing")
		check(contacts == 0 and edges == 0,"Live drafting/pull-out must avoid contacts and road departures")
		print("INDY DRAFT LIVE ",JSON.stringify({"drafting_ticks":drafting_ticks,"peak_tow":peak_tow,"pull_out_gap_m":pull_out_gap,"contacts":contacts,"edge_ticks":edges}))
		# Recover the recorded shape in motion, rather than checking only its order.
		for car in [follower,leader]:
			car.get_node("Driver").set_physics_process(false)
			reset(car)
			car.slipstream_strength = 0.0
			car.slipstream_speed_fraction = 0.0
			car.get_node("Driver").pace_scale = 1.0
		driver.base_lap_target_s = leader.get_node("Driver").base_lap_target_s
		fixture.place(follower,straight,-1,95)
		fixture.place(leader,straight+12,0,95)
		driver.desired_speed_kph = 95*3.6
		craft.opponent = leader
		craft.committed_s = 20
		craft.best_opponent_gap = 12
		contacts = 0
		peak_tow = 0.0
		for car in [follower,leader]:
			car.get_node("Driver").set_physics_process(true)
		for tick in range(240):
			await physics_frame
			peak_tow = maxf(peak_tow,follower.slipstream_strength)
			for car in [follower,leader]:
				if car.car_contact_this_step:
					contacts += 1
		check(peak_tow > .1 and contacts == 0,"Live stalled attack must regain the tow without contact")
		print("INDY DRAFT RECOVERY ",JSON.stringify({"peak_tow":peak_tow,"contacts":contacts,"lane":craft.lane,"state":craft.state}))
	fixture.free()
	main.free()
	for failure in failures:
		push_error(failure)
	print("DRAFT RACECRAFT PASSED" if failures.is_empty() else "DRAFT RACECRAFT FAILED")
	quit(0 if failures.is_empty() else 1)
