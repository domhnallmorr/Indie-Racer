extends "res://tools/compare_tyre_falloff.gd"
## Run with an isolated APPDATA directory: preference checks write user://.
var experimental := false

func make_sim(width: float, _fine := false):
	var sim = Model.new()
	sim.configure(parameters.duplicate(true))
	sim.p.post_peak_falloff = width
	sim.direct_steering = true
	sim.experimental_wheel_motion = experimental
	return sim

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/surfers_tyre_falloff.json"))
	var meta := ConfigFile.new()
	assert(meta.load(fixture.metadata) == OK)
	parameters = meta.get_value("run","physics")
	var reference: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/experimental_handling_reference.json"))
	for enabled in [false,true]:
		experimental = enabled
		for window in fixture.windows:
			var actual := replay(window,fixture.columns,2.0,1)
			var expected: Dictionary = {}
			for row in reference:
				if row.name == window.name and row.variant == ("wheel_motion_fast" if enabled else "baseline"):
					expected = row
			assert(not expected.is_empty())
			check(absf(actual.peak_beta-expected.peak_beta)<.001,"Playable model matches diagnostic prototype: "+window.name)
			for i in range(actual.trace.size()):
				check(absf(actual.trace[i][1]-expected.trace[i][1])<.001,"Full sideslip trace preserved")
			print("PLAYABLE GEOMETRY enabled=%s %s peak=%.3f" % [enabled,window.name,actual.peak_beta])
	var options = root.get_node("DrivingOptions")
	assert(options.set_experimental_handling(false) == OK)
	var connection_count: int = options.handling_changed.get_connections().size()
	for iteration in range(3):
		var temporary = load("res://game/ui/controls_panel.gd").new()
		root.add_child(temporary)
		await process_frame
		check(options.handling_changed.get_connections().size()==connection_count+1,"New controls panel subscribes once")
		temporary.queue_free()
		await process_frame
		check(options.handling_changed.get_connections().size()==connection_count,"Freed controls panel disconnects")
		assert(options.set_experimental_handling(iteration % 2 == 0)==OK)
	assert(options.set_experimental_handling(false)==OK)
	var main = load("res://game/main/main.tscn").instantiate()
	main.ai_enabled = false
	root.add_child(main)
	var player = main.player
	player.driving_enabled = false
	check(not player.sim.experimental_wheel_motion,"Current handling remains initial default")
	var controls = main.get_node("HUD/RaceUI/Shell/Layout/Content/Pages/ControlsPanel")
	var choices: Array[Node] = controls.find_children("HandlingModel","OptionButton",true,false)
	assert(choices.size()==1)
	var choice: OptionButton = choices[0]
	choice.item_selected.emit(1)
	check(player.sim.experimental_wheel_motion and options.experimental_handling,"Controls selection updates live player")
	var saved := ConfigFile.new()
	assert(saved.load(options.SETTINGS_PATH)==OK)
	check(saved.get_value("driving","experimental_handling")==true,"Selection persists")
	player.sim.reset()
	check(player.sim.experimental_wheel_motion,"Reset to pits retains selection")
	choice.item_selected.emit(2)
	check(player.sim.independent_front_rotation and options.independent_front_rotation,"Free-front selection updates live player")
	check(choice.selected==2,"Free-front dropdown stays synchronised")
	assert(saved.load(options.SETTINGS_PATH)==OK)
	check(saved.get_value("driving","independent_front_rotation")==true,"Free-front selection persists")
	player.sim.reset()
	check(player.sim.independent_front_rotation,"Reset retains free-front selection")
	check(player.sim.handling_model_id()=="wheel_contacts_free_front_v2","Free-front telemetry has distinct identity")
	choice.item_selected.emit(1)
	check(not player.sim.independent_front_rotation,"Previous experiment remains available")
	var other := Model.new()
	other.configure(parameters.duplicate(true))
	check(not other.experimental_wheel_motion,"Non-player model remains current")
	assert(player.telemetry.start(player,"res://tmp/experimental_handling_telemetry")==OK)
	await physics_frame
	player.drive_step(1.0/60,0,0,0)
	choice.item_selected.emit(2)
	await physics_frame
	player.drive_step(1.0/60,0,0,0)
	choice.item_selected.emit(0)
	check(not player.sim.experimental_wheel_motion and not options.experimental_handling,"Switch back updates live player")
	await physics_frame
	player.drive_step(1.0/60,0,0,0)
	player.telemetry.stop()
	var csv := FileAccess.open(player.telemetry.path,FileAccess.READ)
	var header := csv.get_csv_line()
	var column := header.find("handling_model")
	check(column>=0,"Telemetry identifies handling per sample")
	var first := csv.get_csv_line()
	var second := csv.get_csv_line()
	var third := csv.get_csv_line()
	check(first[column]=="wheel_contacts_experimental_v1" and second[column]=="wheel_contacts_free_front_v2" and third[column]=="axle_contacts_v1","Telemetry captures all three modes during recording")
	check(first.size()==header.size() and second.size()==header.size() and third.size()==header.size(),"Telemetry rows match schema")
	main.queue_free()
	await process_frame
	check(options.handling_changed.get_connections().size()==connection_count,"Session callbacks disconnect after exit")
	assert(options.set_experimental_handling(true)==OK)
	assert(options.set_experimental_handling(false)==OK)
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("EXPERIMENTAL HANDLING PASSED: 18 full replay traces, live UI switching, saved selection, reset retention, AI isolation and telemetry.")
	quit(0 if failures.is_empty() else 1)
