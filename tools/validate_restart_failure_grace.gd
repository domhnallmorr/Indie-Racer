extends SceneTree
## Restart spacing defers scripted events; mechanical failures are never cancelled.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	root.set_meta("roster_selection",{"session_mode":"race","race_laps":80,"seed":42})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.session.show_green()
	var control = main.race_control
	for car in main.ai_cars:
		car.get_node("Driver").race_plan.failure_progress = INF
	for entry in main.lap_timing.entries:
		entry.laps = 20
		entry.armed = true
		entry.expected = 2
	check(control.scripted_incident_allowed(),"Initial green allows scripted events")
	control.call_caution("Spacing test")
	var driver = main.ai_cars[0].get_node("Driver")
	driver.race_plan.failure_type = driver.race_plan.FailureType.ENGINE
	driver.race_plan.failure_progress = 1.0
	check(not driver.race_plan.update(driver,0.0),"Scheduled mechanical failure waits under yellow")
	control._restart()
	check(not control.scripted_incident_allowed(),"Restart defers scripted events")
	driver.race_plan.update(driver,0.0)
	check(driver.race_plan.retired and control.active(),"Overdue engine failure survives restart and triggers normally")
	control._restart()
	main.incidents.failure_progress = INF
	main.incidents.debris_progress = 0.0
	main.incidents._physics_process(0.0)
	check(is_finite(main.incidents.debris_progress) and not control.active(),"Debris remains pending during spacing")
	for entry in main.lap_timing.entries:
		entry.laps += 9
	check(not control.scripted_incident_allowed(),"Spacing lasts nine leader laps")
	for entry in main.lap_timing.entries:
		entry.laps += 1
	check(control.scripted_incident_allowed(),"Spacing expires at ten leader laps")
	main.incidents._physics_process(0.0)
	check(control.active() and control.reason == "Debris on track" and not is_finite(main.incidents.debris_progress),"Deferred debris triggers once after expiry")
	main.session.finish_race()
	check(not control.scripted_incident_allowed(),"No new incident after finish")
	print("RESTART INCIDENT SPACING ","PASSED" if failures.is_empty() else failures)
	main.free()
	quit(0 if failures.is_empty() else 1)
