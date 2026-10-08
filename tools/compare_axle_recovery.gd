extends "res://tools/compare_tyre_falloff.gd"
## Closed-loop correction at measured sideslip; tyre variants remain diagnostic.
func make_sim(width: float, _fine := false):
	var sim=fine_model.new()
	sim.configure(parameters.duplicate(true))
	sim.p.post_peak_falloff=width
	sim.direct_steering=true
	return sim

func _initialize() -> void:
	var meta:=ConfigFile.new()
	assert(meta.load("res://tools/fixtures/surfers_downshift.cfg")==OK)
	parameters=meta.get_value("run","physics")
	var source:=FileAccess.get_file_as_string("res://game/vehicle/bicycle_model.gd")
	var output: Array=[]
	for variant in ["baseline","front_width4","rear_width3","rear_width4"]:
		var code:=source
		if variant=="front_width4": code=code.replace("/p.post_peak_falloff","/(4.0 if stiffness == p.front_cornering_stiffness_n_rad else p.post_peak_falloff)")
		if variant=="rear_width3": code=code.replace("/p.post_peak_falloff","/(3.0 if stiffness == p.rear_cornering_stiffness_n_rad else p.post_peak_falloff)")
		if variant=="rear_width4": code=code.replace("/p.post_peak_falloff","/(4.0 if stiffness == p.rear_cornering_stiffness_n_rad else p.post_peak_falloff)")
		fine_model=GDScript.new()
		fine_model.source_code=code
		assert(fine_model.reload()==OK)
		for mode in ["power","brake","brake_reverse"]:
			for delay in [0.0,.1,.2,.3]:
				var left:=controlled(2.0,mode,delay,1.0)
				var right:=controlled(2.0,mode,delay,-1.0)
				check(absf(left.peak_beta-right.peak_beta)<.001,"Mirrored "+variant+" "+mode+" recovery")
				left["variant"]=variant
				output.append(left)
				print("AXLE %s %s delay=%.1f peak=%.3f recovery=%.3f" % [variant,mode,delay,left.peak_beta,left.recovery_seconds])
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var file:=FileAccess.open("res://tmp/axle_recovery_results.json",FileAccess.WRITE)
	if file==null:
		push_error("Cannot write axle recovery results")
		quit(1)
		return
	file.store_string(JSON.stringify(output))
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("AXLE RECOVERY PASSED: mirrored power, braking and heavy-braking reversal with 0–0.3 s correction delays. Tyre settings unchanged.")
	quit(0 if failures.is_empty() else 1)
