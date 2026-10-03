extends SceneTree
var failures: Array[String] = []
const RaceControl = preload("res://game/race/race_control.gd")

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	for band in [[100.0,0.0],[70.0,0.0],[69.99,.15],[60.0,.15],[59.99,.30],[40.0,.30],[39.99,.50],[30.0,.50],[29.99,1.0]]:
		check(is_equal_approx(RaceControl.caution_pit_chance(band[0],100,1,120),band[1]),"Fuel band boundary: "+str(band[0]))
	check(RaceControl.caution_pit_chance(11,100,1,10) == 0,"Fuel to finish plus reserve overrides low percentage")
	check(RaceControl.caution_pit_chance(10,100,1,10) == 1,"Finish calculation requires the reserve lap")
	check(RaceControl.caution_pit_chance(90,100,1,99) == 1,"Full tank to finish overrides high percentage")
	check(RaceControl.caution_pit_chance(90,100,1,100) == 0,"Full tank also needs the reserve lap")
	root.set_meta("roster_selection",{"session_mode":"race","race_laps":120,"file":"res://content/rosters/icr2_full/manifest.json","seed":42})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.session.show_green()
	var control = main.race_control
	var driver = main.ai_cars[0].get_node("Driver")
	var state = driver.car.player_state
	state.fuel_capacity_gal = 100
	state.fuel_per_lap_gal = 1
	state.fuel_gal = 50
	control.phase = control.Phase.OPEN
	control.caution_count = 1
	var hits := 0
	for seed_value in range(1000):
		driver.ratings.variation_seed = seed_value
		control._plan_caution_pits()
		var decision: bool = control.should_pit(driver)
		hits += int(decision)
		control._plan_caution_pits()
		check(control.should_pit(driver) == decision,"Same driver and caution seed repeat")
	check(hits > 250 and hits < 350,"30% band produces a mixed field over independent seeds")
	state.fuel_gal = 75
	control._plan_caution_pits()
	check(not control.should_pit(driver),"High fuel stays out")
	state.fuel_gal = 20
	for i in range(100):
		check(not control.should_pit(driver),"Decision stays fixed as fuel burns")
	control.phase = control.Phase.ONE_TO_GREEN
	control.call_caution("Additional incident")
	check(not control.should_pit(driver),"Additional incident does not reroll strategy")
	state.fuel_gal = driver.pit_fuel_trigger_gal
	check(control.should_pit(driver),"Low fuel overrides stay-out decision")
	control.phase = control.Phase.CLOSED
	state.fuel_gal = 1
	check(control.should_pit(driver),"Closed-pit emergency stop remains available")
	state.fuel_gal = 20
	check(not control.should_pit(driver),"Closed pits prohibit normal strategy stops")
	control._restart()
	check(control.caution_pit_decisions.is_empty(),"Restart clears old decisions")
	control.call_caution("Next caution")
	control.phase = control.Phase.OPEN
	control._plan_caution_pits()
	check(control.should_pit(driver),"New caution uses current fuel for a fresh decision")
	control.commit_pit(driver.car)
	check(not control.should_pit(driver),"Pit commitment consumes strategic stop")
	control._plan_caution_pits()
	check(not control.should_pit(driver),"Committed car is not assigned another stop")
	# Leader's progress, rather than a lapped driver's own score, sets range.
	control.committed.clear()
	main.lap_timing.entries[2].laps = 115
	main.lap_timing.entries[2].armed = true
	main.lap_timing.entries[2].expected = 1
	state.fuel_gal = 10
	control._plan_caution_pits()
	check(not control.should_pit(driver),"Lapped car with fuel to reach leader's finish stays out")
	print("CAUTION STRATEGY draws=",hits,"/1000 ","PASSED" if failures.is_empty() else failures)
	main.free()
	quit(0 if failures.is_empty() else 1)
