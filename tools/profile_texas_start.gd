extends SceneTree
class TimedDriver extends "res://game/ai/icr2_driver.gd":
	var costs := {"total":0,"planner":0,"traffic":0,"index":0,"ticks":0}
	func _physics_process(delta: float) -> void:
		var start := Time.get_ticks_usec()
		super._physics_process(delta)
		if practice_session.status == practice_session.Status.RUNNING:
			costs.total += Time.get_ticks_usec()-start
			costs.ticks += 1
	func _planned_speed() -> float:
		var start := Time.get_ticks_usec()
		var value := super._planned_speed()
		costs.planner += Time.get_ticks_usec()-start
		return value
	func _traffic_speed(request: float) -> float:
		var start := Time.get_ticks_usec()
		var value := super._traffic_speed(request)
		costs.traffic += Time.get_ticks_usec()-start
		return value
	func _update_index(position: Vector3) -> void:
		var start := Time.get_ticks_usec()
		super._update_index(position)
		costs.index += Time.get_ticks_usec()-start

class TimedCar extends "res://game/vehicle/icr2_car.gd":
	var costs := {"movement":0,"tow":0,"zones":0,"ticks":0}
	func reference_step(delta: float, target: float, curvature: float) -> void:
		var start := Time.get_ticks_usec()
		super.reference_step(delta,target,curvature)
		costs.movement += Time.get_ticks_usec()-start
		costs.ticks += 1
	func update_slipstream(delta: float) -> void:
		var start := Time.get_ticks_usec()
		super.update_slipstream(delta)
		costs.tow += Time.get_ticks_usec()-start
	func update_zone_state() -> void:
		var start := Time.get_ticks_usec()
		super.update_zone_state()
		costs.zones += Time.get_ticks_usec()-start

func swap_script(node, script) -> void:
	var saved := {}
	for property in node.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			saved[property.name] = node.get(property.name)
	node.set_script(script)
	for property in node.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and saved.has(property.name):
			node.set(property.name,saved[property.name])

## Run headless with --fixed-fps 60; reports wall time per simulation tick.
func _initialize() -> void:
	call_deferred("profile")

func profile() -> void:
	Engine.physics_ticks_per_second = 60
	root.set_meta("roster_selection",{"track_id":"texas","file":"res://content/rosters/irl_2001/manifest.json","seed":42,"session_mode":"race","race_laps":20})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	var baseline := "--baseline" in OS.get_cmdline_user_args()
	var instrument := "--instrument" in OS.get_cmdline_user_args()
	if instrument:
		for car in main.ai_cars:
			swap_script(car,TimedCar)
			swap_script(car.get_node("Driver"),TimedDriver)
	if baseline:
		var old_script = load("res://builds/icr2_driver_before_tow_optimization.gd")
		for car in main.ai_cars:
			var driver = car.get_node("Driver")
			var saved := {}
			for property in driver.get_property_list():
				if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
					saved[property.name] = driver.get(property.name)
			driver.set_script(old_script)
			for property in driver.get_property_list():
				if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and saved.has(property.name):
					driver.set(property.name,saved[property.name])
	# Park the unattended player so it cannot obstruct the starting field.
	main.player.global_transform = main.player.track.global_transform*main.track_data.pit_box_transform()
	main.player.reset_dynamics()
	var green_tick := -1
	var last := Time.get_ticks_usec()
	var samples: Array[float] = []
	var physics: Array[float] = []
	var tow_ticks := 0
	for tick in range(12000):
		await physics_frame
		var now := Time.get_ticks_usec()
		if main.session.status == main.session.Status.RUNNING:
			if green_tick < 0:
				green_tick = tick
				print("TEXAS START green at ",tick/60.0," baseline=",baseline)
				if instrument:
					for car in main.ai_cars:
						for node in [car,car.get_node("Driver")]:
							for key in node.costs:
								node.costs[key] = 0
			if tick > green_tick+60:
				samples.append((now-last)/1000.0)
				physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
			for car in main.ai_cars:
				if car.slipstream_drag_reduction > .01:
					tow_ticks += 1
			if tick-green_tick >= 1800:
				break
		last = now
	if samples.is_empty():
		push_error("Formation did not reach green")
		quit(1)
		return
	samples.sort()
	physics.sort()
	var item := {"baseline":baseline,"cars":main.ai_cars.size(),"tow_ticks":tow_ticks,"median_tick_ms":samples[samples.size()/2],"p95_tick_ms":samples[int(samples.size()*.95)],"p99_tick_ms":samples[int(samples.size()*.99)],"median_physics_ms":physics[physics.size()/2],"p95_physics_ms":physics[int(physics.size()*.95)]}
	print("TEXAS START PROFILE ",JSON.stringify(item))
	if instrument:
		var totals := {}
		for car in main.ai_cars:
			for node in [car,car.get_node("Driver")]:
				for key in node.costs:
					if key != "ticks":
						totals[key] = totals.get(key,0.0)+node.costs[key]/float(maxi(1,node.costs.ticks))/1000.0
		print("TEXAS DRIVER COSTS ",JSON.stringify(totals))
	var file := FileAccess.open("res://builds/texas_start_before.json" if baseline else "res://builds/texas_start_after.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(item,"  "))
	main.free()
	quit()
