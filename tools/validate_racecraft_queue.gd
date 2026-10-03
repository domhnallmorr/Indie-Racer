extends SceneTree
var failures: Array[String] = []
var fixture = preload("res://tools/validate_racecraft.gd").new()
var driver
var fast
var slow
var third
var distant
func _initialize() -> void:
	call_deferred("validate")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
func setup_queue() -> void:
	fixture.place(fast,100,1,100)
	fixture.place(slow,109,1,100)
	fixture.place(third,118,1,100)
	fixture.place(distant,600,0,100)
	var craft = driver.racecraft
	craft.opponent = slow
	craft.cooldown_s = 0
	craft.committed_s = 10
	craft.best_opponent_gap = INF
	craft.no_progress_s = 0
	craft.losing_attempt_s = 0
	craft.queue_car = null
	craft.queue_seconds = 0
	craft.lane_change_blocked = false
	driver.desired_speed_kph = 108*3.6
func setup_losing_attempt(gap_m: float = 30.0) -> void:
	setup_queue()
	fixture.place(slow,100+gap_m,0,100)
	fixture.place(third,300,0,100)
	driver.desired_speed_kph = 100*3.6
	driver.racecraft.best_opponent_gap = 13.0

func think(seconds: float) -> void:
	for tick in range(ceili(seconds*60)):
		driver.racecraft.update(driver,1.0/60.0)
func validate() -> void:
	root.set_meta("roster_selection",{"track_id":"texas" if "--texas" in OS.get_cmdline_user_args() else "michigan","file":"res://content/rosters/irl_2001/manifest.json","seed":745616522,"ai_telemetry":false})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.player.telemetry.stop()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	fast = main.get_node("AI_Calkins")
	slow = main.get_node("AI_Boat")
	third = main.get_node("AI_Buhl")
	distant = main.get_node("AI_GregRay")
	driver = fast.get_node("Driver")
	driver.rivals.assign([fast,slow,third,distant])
	var craft = driver.racecraft
	if "--texas" not in OS.get_cmdline_user_args():
		setup_queue()
		craft.opponent = distant
		think(1.0/60)
		check(craft.opponent == null,"A neighbouring queue must not retain an opponent 500 metres ahead")
		check(craft.cooldown_s > 0,"An abandoned distant attempt must retain its cooldown")
		setup_queue()
		fixture.place(third,100,0,100)
		craft.opponent = distant
		think(1.0/60)
		check(craft.opponent == null and craft.target_lane == 1,"Drop obsolete target while holding lane beside occupied RACE")
		setup_queue()
		think(1)
		check(craft.target_lane == 1,"A short pace fluctuation must not cause a lane switch")
		think(1.1)
		check(craft.target_lane < 1 and craft.opponent == slow,"Sustained faster car at the tail of an outside queue must choose a clear alternative")
		var selected: float = craft.target_lane
		think(.2)
		check(craft.target_lane == selected,"An unfinished lane transition must not be reconsidered")
		setup_queue()
		driver.desired_speed_kph = 100*3.6
		think(3)
		check(craft.target_lane == 1,"Equal desired pace must not trigger a speculative lane switch")
		setup_queue()
		fixture.place(third,94,0,110)
		think(3)
		check(craft.target_lane == 1,"Fast rear traffic in RACE must block both RACE and crossing to inside")
		setup_queue()
		fixture.place(slow,104,1,100)
		think(3)
		check(craft.target_lane == 1,"Insufficient bumper clearance must prevent pulling out")
		setup_queue()
		fixture.place(slow,101,0,100)
		fixture.place(third,180,0,100)
		think(3)
		check(craft.target_lane == 1 and craft.opponent == slow,"Genuine side-by-side passing must keep its established groove")
	setup_losing_attempt()
	var aborts_before: int = craft.aborted
	think(2.8)
	check(craft.opponent == slow,"Losing attempt must persist for the full three-second window")
	think(.3)
	check(craft.opponent == null and craft.target_lane == 0,"Persistently losing attempt must release target and start returning to RACE")
	check(craft.aborted == aborts_before+1 and craft.cooldown_s > 0,"Early abandonment must count once and retain retry cooldown")
	think(1)
	check(craft.opponent == null and is_zero_approx(craft.lane),"Clear return must finish without immediately retrying")
	setup_losing_attempt(18)
	craft.best_opponent_gap = 1
	think(4)
	check(craft.opponent == slow and craft.target_lane == 1,"Close outside battle must survive large historical gap growth")
	setup_losing_attempt(30)
	craft.best_opponent_gap = 25
	think(4)
	check(craft.opponent == slow,"Distant target without eight metres of lost ground must retain commitment")
	setup_losing_attempt()
	think(2)
	fixture.place(slow,118,0,100)
	think(.1)
	fixture.place(slow,130,0,100)
	think(2)
	check(craft.opponent == slow,"Recovery inside twenty metres must reset the losing timer")
	think(1.1)
	check(craft.opponent == null,"A fresh sustained loss must still abandon after recovery")
	setup_losing_attempt()
	fixture.place(third,94,0,110)
	think(3.1)
	check(craft.opponent == null and craft.target_lane == 1 and craft.lane == 1,"Drop failed attack while fast rear traffic blocks return to RACE")
	fixture.place(third,100,0,100)
	think(.5)
	check(craft.target_lane == 1,"A car alongside must continue to receive room after abandonment")
	fixture.place(third,300,0,100)
	think(1)
	check(craft.target_lane == 0 and is_zero_approx(craft.lane),"Return may complete once blocking traffic clears")
	setup_losing_attempt()
	craft.committed_s = 0
	think(4)
	check(craft.opponent == slow,"New attempt must settle before the three-second losing window")
	think(1.1)
	check(craft.opponent == null,"Settled losing attempt must eventually abandon")
	# Equal-speed rear traffic should allow a normal return at ten metres,
	# rather than preserving a passing lane until the old 22/24 m thresholds.
	setup_losing_attempt()
	fixture.place(fast,100,-1,105)
	fixture.place(slow,90,0,105)
	var passes_before: int = craft.passes
	think(1.0/60)
	check(craft.opponent == null and craft.target_lane == 0 and craft.passes == passes_before+1,"Clear rear car must complete the pass and allow returning to RACE")
	check(absf(craft._body_end_extent(fast,true)+craft._body_end_extent(slow,false)-4.35) < .01,"Bumper calculation must use actual open-wheel collision dimensions")
	think(1)
	check(is_zero_approx(craft.lane),"Equal-speed rear car ten metres back must not pin the completed return")
	var intended: Vector3 = craft.path_point(driver,0,0)
	check(craft.ahead(driver,0).distance_to(intended) < .01,"Side-room steering must also release the safely cleared rear car")
	setup_losing_attempt()
	fixture.place(fast,100,-1,105)
	fixture.place(slow,90,0,113)
	think(1.0/60)
	check(craft.opponent == slow and not craft.lane_clear(driver,0),"Fast-closing rear car at ten metres must prevent completion and return")
	setup_losing_attempt()
	fixture.place(fast,100,-1,105)
	fixture.place(slow,95,0,105)
	think(1.0/60)
	check(craft.opponent == slow and not craft.lane_clear(driver,0),"Insufficient bumper margin must keep the established passing lane")
	setup_losing_attempt()
	fixture.place(fast,100,-1,105)
	fixture.place(slow,100,0,105)
	think(1.0/60)
	check(craft.opponent == slow and not craft.lane_clear(driver,0),"Overlapping car must still block a return")
	setup_losing_attempt()
	fixture.place(fast,100,-1,105)
	fixture.place(slow,82,0,105)
	fixture.place(third,98,0,105)
	think(1.0/60)
	check(craft.opponent == null and craft.target_lane == -1,"Completing the target pass must not allow crossing a different overlapping car")
	# Prediction extends beyond the former 24 m window for a long crossing.
	setup_losing_attempt()
	fixture.place(fast,100,-1,105)
	fixture.place(slow,72,1,130)
	think(1.0/60)
	check(not craft.lane_clear(driver,1),"Rapidly closing rear traffic must block a full crossing even beyond 24 metres")
	fixture.free()
	main.free()
	for failure in failures:
		push_error(failure)
	print("RACECRAFT QUEUE PASSED" if failures.is_empty() else "RACECRAFT QUEUE FAILED")
	quit(0 if failures.is_empty() else 1)
