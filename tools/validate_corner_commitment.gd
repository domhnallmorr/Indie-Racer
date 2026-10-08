extends SceneTree
## Ward/Boat T4 regression and lane commitment without disabling safety.
var failures: Array[String] = []
const DT := 1.0/60.0

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func reset(car) -> void:
	var craft = car.get_node("Driver").racecraft
	craft._reset_corner_commitment()
	craft.opponent = null
	craft.draft_leader = null
	craft.cooldown_s = 0.0
	craft.committed_s = 0.0
	craft.best_opponent_gap = INF
	craft.no_progress_s = 0.0
	craft.losing_attempt_s = 0.0
	craft.launch_weight = 0.0
	craft.green_launch_lane_hold_remaining_s = 0.0
	craft.green_launch_guard_remaining_s = 0.0
	craft.lane_change_blocked = false
	craft.lane_clear_seconds = 0.0

func validate() -> void:
	root.set_meta("roster_selection",{"track_id":"indianapolis","file":"res://content/rosters/irl_2001/manifest.json","seed":1967411212,"ai_strength":105})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.player.driving_enabled = false
	for car in main.ai_cars:
		car.get_node("Driver").set_physics_process(false)
	var ward = main.get_node("AI_JeffWard")
	var boat = main.get_node("AI_Boat")
	var sharpe = main.get_node("AI_Sharpe")
	var driver = ward.get_node("Driver")
	var craft = driver.racecraft
	var fixture = load("res://tools/validate_racecraft.gd").new()
	var group: Array[Node3D] = [ward,boat,sharpe]
	for car in group:
		reset(car)
		car.player_state.request_departure()
		car.player_state.is_in_pit_lane = false
		car.player_state.is_in_pit_speed_zone = false
		car.get_node("Driver").rivals.assign(group)
	check(craft.authored_corners and craft.corner_regions[1500] == "turn_4","Indy must load the authored T4 region")
	# Recorded 143.95 s decision: 18 m to Boat, 2.98 km/h pace advantage,
	# Sharpe 21 m behind. The old planner selected OUTSIDE in mid-T4.
	fixture.place(ward,driver.race_distances[1500],0,350.82/3.6)
	fixture.place(boat,driver.race_distances[1500]+18.06,0,347.84/3.6)
	fixture.place(sharpe,driver.race_distances[1500]-20.95,0,348.78/3.6)
	driver.desired_speed_kph = 350.82
	var attempts_before: int = craft.attempts
	craft.update(driver,DT)
	check(craft.corner_id == "turn_4" and craft.target_lane == 0 and craft.opponent == null and craft.attempts == attempts_before,"Ward must hold RACE instead of initiating an outside pass in T4")
	check(craft.state == "corner_hold","Telemetry must identify the corner hold")
	# At the exit the same opportunity can be evaluated again (tow first).
	fixture.place(ward,driver.race_distances[1700],0,350.82/3.6)
	fixture.place(boat,driver.race_distances[1700]+18.06,0,347.84/3.6)
	fixture.place(sharpe,driver.race_distances[1700]-60,0,348.78/3.6)
	craft.update(driver,DT)
	check(craft.corner_id.is_empty() and craft.state == "drafting" and craft.draft_leader == boat,"Release the corner lock and regain the tow on exit")
	# A pull-out selected before entry continues rather than snapping to RACE.
	reset(ward)
	fixture.place(ward,driver.race_distances[1450],-.2,95)
	fixture.place(boat,driver.race_distances[1450]+40,0,95)
	fixture.place(sharpe,driver.race_distances[1450]-100,0,95)
	craft.target_lane = -1
	craft.opponent = boat
	craft.committed_s = 1
	driver.desired_speed_kph = 95*3.6
	craft.update(driver,DT)
	check(craft.corner_lane == -1 and craft.target_lane == -1 and craft.lane < -.2 and not craft.lane_change_blocked,"Finish a safe pre-entry lane blend on the selected groove")
	# An unsafe continuation pauses while retaining its destination.
	fixture.place(boat,driver.race_distances[1450]+1,-.6,95)
	var lane_before: float = craft.lane
	craft.update(driver,DT)
	check(craft.target_lane == -1 and craft.lane == lane_before and craft.lane_change_blocked,"Pause an unsafe blend even while the corner lane is committed")
	# A completed pass inside the corner must not immediately move back to RACE.
	fixture.place(ward,driver.race_distances[1550],-1,95)
	fixture.place(boat,driver.race_distances[1550]-20,0,95)
	fixture.place(sharpe,driver.race_distances[1550]-100,0,95)
	craft.committed_s = 3
	craft.update(driver,DT)
	check(craft.opponent == null and craft.target_lane == -1 and craft.corner_id == "turn_4","Complete the pass but retain its groove until corner exit")
	fixture.place(ward,driver.race_distances[1700],-1,95)
	fixture.place(boat,driver.race_distances[1700]-20,0,95)
	fixture.place(sharpe,driver.race_distances[1700]-100,0,95)
	craft.update(driver,DT)
	check(craft.corner_id.is_empty() and craft.target_lane == 0,"Allow a safe return to RACE after the corner")
	# Queue replanning and drafting cannot reverse an established corner groove.
	reset(ward)
	fixture.place(ward,driver.race_distances[1550],1,95)
	fixture.place(boat,driver.race_distances[1550]+9,1,95)
	craft.opponent = boat
	craft.committed_s = 10
	driver.desired_speed_kph = 105*3.6
	for tick in range(181):
		craft.update(driver,DT)
	check(craft.corner_lane == 1 and craft.target_lane == 1 and craft.draft_leader == null and craft.queue_seconds == 0,"Do not reconsider a corner queue's groove mid-turn")
	# Longitudinal protection still brakes for a stopped same-lane leader.
	fixture.place(boat,driver.race_distances[1550]+10,1,0)
	craft.update(driver,DT)
	check(craft.traffic_speed(driver,95) < 95 and driver.traffic_reason.begins_with("collision_guard_"),"Corner commitment must preserve collision braking")
	# Side-room steering remains available for existing overlap.
	fixture.place(ward,driver.race_distances[1550],1,95)
	fixture.place(boat,driver.race_distances[1550]+2,0,95)
	craft.update(driver,DT)
	var bounds: Vector3 = craft._side_room_bounds(driver)
	check(bounds.z == 1 and bounds.x > -8,"Keep side-room steering active during overlap")
	# Verify every authored file, including the Mile Oval seam-wrapping region.
	for track in ["indianapolis","michigan","texas","mile_oval"]:
		var directory: String = "res://content/tracks/"+track+"/ai/"
		var corridor: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+"racing_corridor.json"))
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory+"corner_regions.json"))
		var race := PackedVector3Array()
		for point in corridor.reference_points.slice(0,-1):
			race.append(Vector3(point[0],point[1],point[2]))
		var probe = preload("res://game/ai/racecraft.gd").new()
		probe.configure(corridor,race,{},data)
		check(probe.enabled and probe.authored_corners,"Valid authored corner data: "+track)
		for region in data.regions:
			check(probe.corner_regions[int(region.entry_index)] == region.id and probe.corner_regions[posmod(int(region.exit_index)-1,race.size())] == region.id,"Region must include its entry and exclude its exit: "+track+"/"+region.id)
		if track == "mile_oval":
			check(probe.corner_regions[0] == "turns_3_4","Retain a corner commitment across the lap seam")
		if track == "indianapolis":
			data.regions[0].entry_point[0] += 1
			probe.configure(corridor,race,{},data)
			check(not probe.authored_corners and not probe.corner_regions[1500].is_empty() and probe.corner_regions[1800].is_empty(),"Stale markers must fall back to stable curvature regions")
	# Pit/formation transitions discard an old corner commitment.
	driver.mode = 1
	craft.update(driver,DT)
	check(craft.corner_id.is_empty(),"Leaving racing must clear corner commitment")
	if "--live" in OS.get_cmdline_user_args():
		for car in group:
			reset(car)
			car.get_node("Driver").practice_cycle = false
			car.get_node("Driver").race_pit_cycle = false
		fixture.place(ward,driver.race_distances[1446],0,347.9/3.6)
		fixture.place(boat,driver.race_distances[1446]+18.8,0,345.1/3.6)
		fixture.place(sharpe,driver.race_distances[1446]-20,0,345.6/3.6)
		for car in group:
			car.get_node("Driver").set_physics_process(true)
		var corner_ticks := 0
		var lane_changes := 0
		var contacts := 0
		var edges := 0
		var exit_decision := false
		for tick in range(600):
			await physics_frame
			if craft.corner_id == "turn_4":
				corner_ticks += 1
				if craft.target_lane != 0:
					lane_changes += 1
			elif corner_ticks > 0 and (craft.state == "drafting" or craft.opponent != null):
				exit_decision = true
			for car in group:
				if car.car_contact_this_step:
					contacts += 1
				if absf(car.get_node("Driver").racecraft.coordinates(car.get_node("Driver"),car).y) > 9:
					edges += 1
		check(corner_ticks > 120 and lane_changes == 0 and exit_decision,"Live Ward must hold his lane through T4 and reassess after exit")
		check(contacts == 0 and edges == 0,"Live T4 commitment must avoid contacts and departures")
		print("CORNER LIVE ",JSON.stringify({"corner_ticks":corner_ticks,"tactical_lane_changes":lane_changes,"exit_decision":exit_decision,"contacts":contacts,"edge_ticks":edges}))
	fixture.free()
	main.free()
	for failure in failures:
		push_error(failure)
	print("CORNER COMMITMENT PASSED" if failures.is_empty() else "CORNER COMMITMENT FAILED")
	quit(0 if failures.is_empty() else 1)
