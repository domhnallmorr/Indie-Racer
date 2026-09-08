extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func cross_gate(timing: Node, entry: Dictionary, gate_index: int, at: float, reverse := false) -> void:
	var gate: Dictionary = timing.gates[gate_index]
	var center := Vector3(gate.point[0],.1,gate.point[2])
	var normal := Vector3(gate.normal[0],0,gate.normal[2])
	if reverse:
		normal = -normal
	entry.previous = center-normal*2
	timing.sample(entry,center+normal*2,at-1,at+1)

func validate() -> void:
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 8
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	var timing = main.lap_timing
	var entry: Dictionary = timing.entries[0]
	entry.previous = Vector3(60,.1,101)
	timing.sample(entry,Vector3(64,.1,101),0,1)
	check(not entry.armed,"Pit lane does not cross race timing gate")
	cross_gate(timing,entry,0,1)
	check(entry.laps == 0 and entry.armed,"Out-lap arms timer without increment")
	for gate in [1,2,3,0]:
		cross_gate(timing,entry,gate,21 if gate == 0 else 1+gate*5)
	check(entry.laps == 1 and is_equal_approx(entry.last,20),"Full lap measured with interpolated crossing")
	cross_gate(timing,entry,0,23,true)
	cross_gate(timing,entry,0,25)
	check(entry.laps == 1,"Reverse and recross gives no lap")
	cross_gate(timing,entry,0,30)
	check(entry.laps == 1,"Skipping checkpoints gives no lap")
	for gate in [1,2,3,0]:
		cross_gate(timing,entry,gate,40 if gate == 0 else 30+gate*2)
	check(entry.laps == 2 and is_equal_approx(entry.best,10),"Faster lap updates personal best")
	timing.invalidate(main.player)
	check(not entry.armed and entry.laps == 2 and entry.best == 10,"Reset preserves results and invalidates current lap")
	check(timing.standings()[0].name == "Player","Practice ranks timed driver first")
	check(timing.format_lap(119.9999) == "2:00.000","Millisecond rollover formatting")
	# Restore player results before live simulation and render.
	entry.laps = 0
	entry.last = 0.0
	entry.best = 0.0
	var panel = main.get_node("HUD/TimingPanel")
	var key := InputEventKey.new()
	key.keycode = KEY_9
	key.pressed = true
	panel._unhandled_input(key)
	check(panel.visible,"9 opens panel")
	panel._unhandled_input(key)
	check(not panel.visible,"9 hides panel")
	for i in range(3000):
		await physics_frame
	for i in [1,2]:
		var result: Dictionary = timing.entries[i]
		check(result.laps >= 1 and result.best > 20 and result.best < 45,"AI completes a plausible timed lap: "+result.name)
		print("%s laps=%s best=%s last=%s" % [result.name,result.laps,timing.format_lap(result.best),timing.format_lap(result.last)])
	panel.show()
	panel.refresh()
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/timing_panel.png")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("TIMING CHECK PASSED: laps, best times, checkpoints, reverse/reset, ranking, toggle, live AI.")
	quit(0 if failures.is_empty() else 1)
