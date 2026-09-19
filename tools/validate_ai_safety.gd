extends SceneTree
var failures: Array[String] = []
const DT := 1.0/60.0

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func validate() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	var fast = main.ai_cars[-1]
	var slow = main.ai_cars[0]
	var driver = fast.get_node("Driver")
	var craft = driver.racecraft
	var peak_clean := 0.0
	var peak_passing := 0.0
	for car in main.ai_cars:
		var d = car.get_node("Driver")
		d.racecraft.opponent = slow if car != slow else fast
		d.racecraft.lane = 1
		d.racecraft.target_lane = 1
		for reference in d.reference_speeds:
			var clean: float = d._scaled_reference_speed(reference)
			peak_clean = maxf(peak_clean,clean*3.6)
			peak_passing = maxf(peak_passing,clean*d.racecraft.speed_factor()*3.6)
			check(is_equal_approx(d._scaled_reference_speed(d.reference_peak_speed*.75),d.reference_peak_speed*.75*d.effective_pace_scale()),"Corner pace ratings remain intact")
	check(peak_clean <= 315 and peak_passing <= 322,"Straight-line speeds must stay close to recorded player reference")
	check(driver._scaled_reference_speed(driver.reference_peak_speed) > slow.get_node("Driver")._scaled_reference_speed(driver.reference_peak_speed),"Retain individual straight-line differences")
	print("SPEED peak_clean_kph=",peak_clean," peak_passing_kph=",peak_passing)
	# Integrate the actual collision guard and reference acceleration/braking
	# limits against a stopped car, a slower car, and sudden hard braking.
	driver.mode = 2
	craft.lane = 0
	craft.target_lane = 0
	craft.own = Vector2(0,craft.lane_lateral(driver,0,0))
	for scenario in ["stopped","closing","braking"]:
		var separation := 300.0 if scenario == "stopped" else (65.0 if scenario == "closing" else 18.0)
		fast.speed_mps = 85.0 if scenario != "braking" else 70.0
		slow.speed_mps = 0.0 if scenario == "stopped" else (45.0 if scenario == "closing" else 70.0)
		var minimum_gap := separation
		for tick in range(900):
			if scenario == "braking" and tick > 30:
				slow.speed_mps = maxf(0,slow.speed_mps-18.0*DT)
			craft.nearby.assign([{"car":slow,"gap":separation,"lateral":craft.own.y}])
			var request: float = craft.traffic_speed(driver,85)
			fast.speed_mps = move_toward(fast.speed_mps,request,(fast.acceleration_limit if request > fast.speed_mps else fast.braking_limit)*DT)
			separation += (slow.speed_mps-fast.speed_mps)*DT
			minimum_gap = minf(minimum_gap,separation)
		check(minimum_gap > 4.35,scenario+" must avoid bumper contact")
		print("AVOIDANCE ",scenario," minimum_gap_m=",minimum_gap)
	# Occupy the swept path after a pass has already begun.
	var fixture = load("res://tools/validate_racecraft.gd").new()
	fixture.place(fast,130,0,65)
	fixture.place(slow,138,.5,65)
	craft.opponent = slow
	craft.target_lane = 1
	craft.update(driver,DT)
	check(craft.lane_change_blocked and craft.lane == 0,"A newly occupied lane must halt an ongoing transition")
	check(craft.ahead(driver,20).distance_to(craft.path_point(driver,20,craft.lane)) < .001,"Steering preview must respect a blocked transition")
	fixture.free()
	main.free()
	for failure in failures:
		push_error(failure)
	print("AI SAFETY PASSED" if failures.is_empty() else "AI SAFETY FAILED")
	quit(0 if failures.is_empty() else 1)
