extends SceneTree
## Record a 60 Hz closed-loop pilot, then replay identical held controls.
## --fixed-fps accelerates headless execution without changing physics delta.
var main
var pilot
var car
var failures: Array[String] = []

class CaptureCar extends "res://game/vehicle/player_bicycle.gd":
	var last_controls := Vector3.ZERO
	var stress_mode := false
	var stress_elapsed := 0.0
	func drive_step(dt: float, gas: float, brake: float, steer: float, direct := false) -> void:
		if stress_mode:
			stress_elapsed += dt
			# Additional steering demand followed by a lift; the pilot may catch it.
			if stress_elapsed >= 12 and stress_elapsed < 13:
				steer *= 1+.35*sin(PI*(stress_elapsed-12))
			if stress_elapsed >= 13 and stress_elapsed < 13.4: gas = 0
		last_controls = Vector3(gas,brake,steer)
		super.drive_step(dt,gas,brake,steer,direct)

func _initialize() -> void:
	call_deferred("run")

func variables(object: Object) -> Dictionary:
	var saved := {}
	for property in object.get_property_list():
		if not (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
		var value = object.get(property.name)
		if contains_object(value): continue
		saved[property.name] = value.duplicate(true) if value is Dictionary or value is Array else value
	return saved

func contains_object(value) -> bool:
	if value is Object: return true
	if value is Array:
		for item in value:
			if contains_object(item): return true
	if value is Dictionary:
		for key in value:
			if contains_object(value[key]): return true
	return false

func restore(object: Object, saved: Dictionary) -> void:
	for key in saved:
		var value = saved[key]
		object.set(key,value.duplicate(true) if value is Dictionary or value is Array else value)

func setup(track_id: String, hz: int) -> void:
	Engine.physics_ticks_per_second = hz
	Engine.time_scale = 1
	root.set_meta("roster_selection",{"track_id":track_id,"session_mode":"private_testing","seed":123,"incident_mode":"off"})
	main = load("res://game/main/main.tscn").instantiate()
	main.ai_enabled = false
	root.add_child(main)
	await physics_frame
	car = main.player
	car.set_physics_process(false)
	var original := {}
	for property in car.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: original[property.name] = car.get(property.name)
	car.set_script(CaptureCar)
	for key in original: car.set(key,original[key])
	car.player_state.pit_stall_state = car.player_state.StallState.NONE
	pilot = load("res://game/ai/oval_driver.gd").new()
	pilot.name = "Driver"
	car.add_child(pilot)
	pilot.set_physics_process(false)
	var path := "res://content/tracks/"+track_id+"/ai/"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path+"race_line.json"))
	data.racing_corridor = JSON.parse_string(FileAccess.get_file_as_string(path+"racing_corridor.json"))
	pilot.configure(car,data,0)
	var placer = load("res://tools/validate_racecraft.gd").new()
	placer.place(car,100,0,0)
	placer.free()
	car.sim.gear = 0
	for tick in range(2*hz):
		await physics_frame
		car.drive_step(1.0/hz,0,1,0)
	car.sim.gear = 4
	car.sim.u = 60
	car.sim.front_left_omega = 60/car.sim.p.front_radius_m
	car.sim.front_right_omega = car.sim.front_left_omega
	car.sim.rear_left_omega = 60/car.sim.p.rear_radius_m
	car.sim.rear_right_omega = car.sim.rear_left_omega
	car.sim.front_omega = car.sim.front_left_omega
	car.sim.rear_omega = car.sim.rear_left_omega
	car.sim.engine_omega = car.sim.rear_omega*car.sim.ratio()
	car.sim.clutch = 1
	car.velocity = -car.global_basis.z*60
	car.speed_mps = 60

func metrics() -> Dictionary:
	return {"samples":[],"lost_support_s":0.0,"wall_events":0,"peak_sideslip_deg":0.0,"peak_wheel_load_n":0.0,"peak_roll_deg":0.0,"min_speed_kph":INF,"nonfinite":false}

func observe(output: Dictionary, dt: float) -> void:
	var support: bool = car.sim.suspension.has_support() if car._suspension_owns_support() else car.is_on_floor()
	if not support: output.lost_support_s += dt
	if not car.wall_impact_this_step.is_empty(): output.wall_events += 1
	output.peak_sideslip_deg = maxf(output.peak_sideslip_deg,absf(rad_to_deg(atan2(car.sim.v,maxf(absf(car.sim.u),.001)))))
	output.peak_roll_deg = maxf(output.peak_roll_deg,absf(rad_to_deg(car.sim.suspension.roll)))
	output.min_speed_kph = minf(output.min_speed_kph,car.speed_mps*3.6)
	output.nonfinite = output.nonfinite or not car.global_position.is_finite()
	for load_n in car.sim.wheel_loads:
		output.nonfinite = output.nonfinite or not is_finite(load_n)
		output.peak_wheel_load_n = maxf(output.peak_wheel_load_n,load_n)

func sample() -> Dictionary:
	return {"position":[car.global_position.x,car.global_position.y,car.global_position.z],"yaw_deg":rad_to_deg(car.rotation.y),"speed_kph":car.speed_mps*3.6,"wheel_loads_n":Array(car.sim.wheel_loads)}

func run() -> void:
	var track_id := "indianapolis"
	var utilisation := .92
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track="): track_id = arg.trim_prefix("--track=")
		if arg.begins_with("--utilisation="): utilisation = float(arg.trim_prefix("--utilisation="))
	await setup(track_id,60)
	pilot.cornering_utilisation = utilisation
	var start := {"car":variables(car),"sim":variables(car.sim),"suspension":variables(car.sim.suspension),"player_state":variables(car.player_state),"transform":car.global_transform,"velocity":car.velocity}
	car.stress_mode = utilisation > 1
	var controls := []
	var recorded := metrics()
	var max_seconds := 180
	for tick in range(max_seconds*60):
		await physics_frame
		pilot._physics_process(1.0/60)
		controls.append([car.last_controls.x,car.last_controls.y,car.last_controls.z])
		observe(recorded,1.0/60)
		recorded.samples.append(sample())
		if pilot.laps >= 1: break
		if tick > 10*60 and (car.speed_mps < -5 or recorded.peak_sideslip_deg > 60):
			recorded.stop_reason = "Reverse motion or severe spin; lap attempt terminated"
			break
	recorded.completed_laps = pilot.laps
	recorded.max_line_error_m = pilot.max_line_error_m
	car.telemetry.stop()
	main.free()
	await physics_frame
	var output := {"track":track_id,"utilisation":utilisation,"duration_s":controls.size()/60.0,"recorded":recorded,"controls":controls,"replays":[],"note":"Pilot-generated fixed inputs; no human driving assessment. 60 Hz generated controls, common initial state. Fixed-fps timing is not displayed FPS."}
	for hz in [60,120]:
		await setup(track_id,hz)
		restore(car,start.car)
		restore(car.sim,start.sim)
		restore(car.sim.suspension,start.suspension)
		restore(car.player_state,start.player_state)
		car.global_transform = start.transform
		car.velocity = start.velocity
		await physics_frame
		var replay := metrics()
		replay.hz = hz
		for input in controls:
			for sub in range(hz/60):
				await physics_frame
				car.drive_step(1.0/hz,input[0],input[1],input[2])
				observe(replay,1.0/hz)
			replay.samples.append(sample())
		output.replays.append(replay)
		car.telemetry.stop()
		main.free()
		await physics_frame
	# Also let the pilot correct its line at 120 Hz. Open-loop divergence alone
	# cannot tell us whether a rate drives better or worse.
	await setup(track_id,120)
	restore(car,start.car)
	restore(car.sim,start.sim)
	restore(car.sim.suspension,start.suspension)
	restore(car.player_state,start.player_state)
	car.global_transform = start.transform
	car.velocity = start.velocity
	pilot.cornering_utilisation = utilisation
	car.stress_mode = utilisation > 1
	var closed := metrics()
	for tick in range(max_seconds*120):
		await physics_frame
		pilot._physics_process(1.0/120)
		observe(closed,1.0/120)
		if tick % 2 == 1: closed.samples.append(sample())
		closed.duration_s = (tick+1)/120.0
		if pilot.laps >= 1: break
		if tick > 10*120 and (car.speed_mps < -5 or closed.peak_sideslip_deg > 60):
			closed.stop_reason = "Reverse motion or severe spin; lap attempt terminated"
			break
	closed.completed_laps = pilot.laps
	output.closed_loop_120 = closed
	var closed_summary := closed.duplicate(true)
	closed_summary.erase("samples")
	print("CLOSED LAP ",track_id," utilisation=",utilisation," hz=120 ",JSON.stringify(closed_summary))
	car.telemetry.stop()
	main.free()
	await physics_frame
	DirAccess.make_dir_recursive_absolute("res://builds")
	var path := "res://builds/lap_rates_%s_%d.json" % [track_id,roundi(utilisation*100)]
	var file := FileAccess.open(path,FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(output,"  "))
	file.close()
	for replay in output.replays:
		var maximum_position := 0.0
		var maximum_heading := 0.0
		var maximum_speed := 0.0
		for i in range(controls.size()):
			var reference: Dictionary = recorded.samples[i]
			var actual: Dictionary = replay.samples[i]
			maximum_position = maxf(maximum_position,Vector3(actual.position[0],actual.position[1],actual.position[2]).distance_to(Vector3(reference.position[0],reference.position[1],reference.position[2])))
			maximum_heading = maxf(maximum_heading,absf(wrapf(actual.yaw_deg-reference.yaw_deg,-180,180)))
			maximum_speed = maxf(maximum_speed,absf(actual.speed_kph-reference.speed_kph))
		replay.erase("samples")
		print("LAP RATE ",track_id," utilisation=",utilisation," duration=",output.duration_s," recorded_laps=",recorded.completed_laps," replay=",JSON.stringify(replay)," max_position_error_m=",maximum_position," max_heading_error_deg=",maximum_heading," max_speed_error_kph=",maximum_speed)
		if replay.nonfinite: failures.append("Nonfinite replay")
	if recorded.completed_laps < 1: push_warning("Pilot did not complete a lap; report is an attempted-lap diagnostic")
	quit(0 if failures.is_empty() else 1)
