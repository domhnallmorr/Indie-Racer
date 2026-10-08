extends "res://tools/compare_tyre_falloff.gd"
## Offline experiment only: validates the retained reference, not the driving solver.
## Keep outer input/automatic-shift decisions at 60 Hz while refining forces.

func refined_model(scale: float, euler := false) -> GDScript:
	var code := FileAccess.get_file_as_string("res://tools/fixtures/step_doubling_reference.gd")
	assert(code.contains("MAX_INTEGRATION_STEP_S := .0005") and code.contains(".8/clutch_rate"))
	code = code.replace("MAX_INTEGRATION_STEP_S := .0005","MAX_INTEGRATION_STEP_S := "+str(.0005*scale)).replace(".8/clutch_rate",str(.8*scale)+"/clutch_rate")
	code = code.replace("SHIFT_INTEGRATION_STEP_S := .000125","SHIFT_INTEGRATION_STEP_S := "+str(.000125*scale))
	if euler:
		# Independent first-order reference: bypass extrapolation entirely.
		var call := "_integrate(dt,gas,brake,steering_input,gravity_forward,gravity_left,normal_gravity,grounded,grip_scale,speed_cap_mps)"
		assert(code.contains(call))
		code = code.replace(call,call.replace("_integrate(","_integrate_euler("))
	var script := GDScript.new()
	script.source_code = code
	assert(script.reload() == OK)
	return script

func max_trace_error(a: Dictionary, b: Dictionary, column: int) -> float:
	var error := 0.0
	for i in range(a.trace.size()): error=maxf(error,absf(a.trace[i][column]-b.trace[i][column]))
	return error

func _initialize() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/surfers_tyre_falloff.json"))
	var meta := ConfigFile.new()
	assert(meta.load(fixture.metadata)==OK)
	parameters=meta.get_value("run","physics")
	var standard := refined_model(1.0)
	var fine := refined_model(.5)
	var rows: Array=[]
	for window in fixture.windows:
		fine_model=standard
		var current := replay(window,fixture.columns,2.0,2)
		fine_model=fine
		var reference := replay(window,fixture.columns,2.0,2)
		var beta_error := max_trace_error(current,reference,1)
		var yaw_error := max_trace_error(current,reference,2)
		check(beta_error<.2,window.name+": full sideslip trace agrees within 0.2 degrees on refinement")
		check(yaw_error<.5,window.name+": full yaw trace agrees within 0.5 degrees/s on refinement")
		print("ACCURACY %s peak=%.4f half=%.4f max_beta_error=%.4f max_yaw_error=%.4f" % [window.name,current.peak_beta,reference.peak_beta,beta_error,yaw_error])
		rows.append({"name":window.name,"peak":current.peak_beta,"refined_peak":reference.peak_beta,"max_beta_error":beta_error,"max_yaw_error":yaw_error})
		if window.name=="heavy_trail_brake":
			fine_model=refined_model(.03125,true)
			var first_order := replay(window,fixture.columns,2.0,2)
			fine_model=refined_model(.015625,true)
			var first_order_fine := replay(window,fixture.columns,2.0,2)
			check(max_trace_error(first_order,first_order_fine,1)<.1,"Independent Euler reference converges within 0.1 degrees")
			check(max_trace_error(current,first_order_fine,1)<.2,"Offline reference agrees with independent fine Euler reference within 0.2 degrees")
			check(max_trace_error(current,first_order_fine,2)<.5,"Yaw agrees with independent fine Euler reference")
			print("INDEPENDENT EULER peaks=",first_order.peak_beta," / ",first_order_fine.peak_beta," reference=",current.peak_beta)
	# Projection boundaries must not create reverse motion or control overshoot.
	for direction in [-1.0,1.0]:
		var sim=standard.new()
		sim.configure(parameters.duplicate(true))
		sim.automatic=false
		sim.gear=0
		sim.u=direction*5.0
		sim.front_omega=sim.u/parameters.front_radius_m
		sim.rear_omega=sim.u/parameters.rear_radius_m
		for i in range(180):
			sim.advance(1.0/60,0,1,0)
			check(sim.u*direction>=-.000001,"Braking to rest does not reverse body velocity")
			check(sim.front_omega*direction>=-.000001 and sim.rear_omega*direction>=-.000001,"Braking does not reverse a stopped wheel")
			check(sim.clutch>=0 and sim.clutch<=1 and sim.throttle>=0 and sim.throttle<=1 and sim.shift_remaining>=0,"Controls remain bounded")
		check(sim.u==0 and sim.front_omega==0 and sim.rear_omega==0,"Parked state settles exactly")
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var file := FileAccess.open("res://tmp/integration_accuracy_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"))
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("INTEGRATION ACCURACY PASSED: all nine full traces, independent Euler reference and bounded forward/reverse stops.")
	quit(0 if failures.is_empty() else 1)
