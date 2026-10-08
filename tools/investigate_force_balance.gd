extends "res://tools/compare_tyre_falloff.gd"
## Counterfactuals are diagnostics only; no settings or production code are edited.
## Several variants deliberately remove physical terms to isolate influence;
## they are not candidate vehicle configurations. Retained controls are open-loop.
func _initialize() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/surfers_tyre_falloff.json"))
	var meta := ConfigFile.new()
	assert(meta.load(fixture.metadata)==OK)
	parameters = meta.get_value("run","physics")
	var original: Dictionary = parameters.duplicate(true)
	var source := FileAccess.get_file_as_string("res://game/vehicle/bicycle_model.gd")
	var output: Array = []
	for variant in ["baseline","front_width4","rear_width4","no_front_brake_yaw","no_pitch_transfer","no_roll_transfer","half_engine_brake","abs_06","step_025","step_0125","step_00625","step_003125"]:
		parameters = original.duplicate(true)
		var code := source
		if variant == "front_width4": code=code.replace("/p.post_peak_falloff","/(4.0 if stiffness == p.front_cornering_stiffness_n_rad else p.post_peak_falloff)")
		if variant == "rear_width4": code=code.replace("/p.post_peak_falloff","/(4.0 if stiffness == p.rear_cornering_stiffness_n_rad else p.post_peak_falloff)")
		if variant == "no_front_brake_yaw": code=code.replace("a*front_y-b*rear.y","a*(front.y*cos(steer)+maxf(front.x,0.0)*sin(steer))-b*rear.y")
		if variant == "no_pitch_transfer": code=code.replace("load_transfer_n = clampf(vehicle_mass_kg*load_transfer_acceleration*p.cg_height_m/p.wheelbase_m,-weight*.35,weight*.35)","load_transfer_n = 0.0")
		if variant == "no_roll_transfer": parameters.front_track_m=100000.; parameters.rear_track_m=100000.
		if variant == "half_engine_brake":
			for i in range(parameters.torque_curve.size()): parameters.torque_curve[i].y *= .5
		if variant == "abs_06": parameters.braking_slip_limit=.06
		var factor := 1.0
		if variant == "step_025": factor=.5
		if variant == "step_0125": factor=.25
		if variant == "step_00625": factor=.125
		if variant == "step_003125": factor=.0625
		code=code.replace("MAX_INTEGRATION_STEP_S := .0005","MAX_INTEGRATION_STEP_S := "+str(.0005*factor)).replace(".8/clutch_rate",str(.8*factor)+"/clutch_rate")
		code=code.replace("SHIFT_INTEGRATION_STEP_S := .000125","SHIFT_INTEGRATION_STEP_S := "+str(.000125*factor))
		fine_model = GDScript.new()
		fine_model.source_code=code
		assert(fine_model.reload()==OK)
		for w in fixture.windows:
			if factor<.5 and w.name!="heavy_trail_brake": continue
			var row := replay(w,fixture.columns,2.0,2)
			# Recorded controls used the older first-order integrator; their
			# trajectory is historical evidence, not today's accuracy reference.
			row["variant"]=variant
			output.append(row)
			print("BALANCE %s %s peak=%.3f yaw=%.3f" % [variant,w.name,row.peak_beta,row.peak_yaw])
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var file := FileAccess.open("res://tmp/force_balance_counterfactuals.json",FileAccess.WRITE)
	if file == null:
		push_error("Cannot write force balance diagnostics")
		quit(1)
		return
	file.store_string(JSON.stringify(output))
	for failure in failures: push_error(failure)
	print("FORCE BALANCE: ",output.size()," diagnostic windows; no vehicle settings changed.")
	quit(0 if failures.is_empty() else 1)
