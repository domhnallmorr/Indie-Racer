extends SceneTree
## Instrument actual driver calls without warming the planner a second time.
class TimedCar extends "res://game/vehicle/player_bicycle.gd":
	var movement_costs := {"movement":0,"step":0,"zones":0,"ticks":0}
	func drive_step(delta: float,gas: float,brake: float,steering: float) -> void:
		var start := Time.get_ticks_usec()
		super.drive_step(delta,gas,brake,steering)
		movement_costs.movement += Time.get_ticks_usec()-start
		movement_costs.ticks += 1
	func _try_surface_step(motion: Vector3) -> void:
		var start := Time.get_ticks_usec()
		super._try_surface_step(motion)
		movement_costs.step += Time.get_ticks_usec()-start
	func update_zone_state() -> void:
		var start := Time.get_ticks_usec()
		super.update_zone_state()
		movement_costs.zones += Time.get_ticks_usec()-start

class TimedModel extends "res://game/vehicle/bicycle_model.gd":
	var integration_usec := 0
	func advance(delta: float,gas: float,brake: float,steering_input: float,gf: float=0,gl: float=0,ng: float=9.81,grounded: bool=true,grip: float=1,cap: float=INF) -> void:
		var start := Time.get_ticks_usec()
		super.advance(delta,gas,brake,steering_input,gf,gl,ng,grounded,grip,cap)
		integration_usec += Time.get_ticks_usec()-start

class TimedDriver extends "res://game/ai/oval_driver.gd":
	var costs := {"driver":0,"planner":0,"corner":0,"index":0,"traffic":0,"ticks":0}
	func _physics_process(delta: float) -> void:
		var start := Time.get_ticks_usec()
		super._physics_process(delta)
		costs.driver += Time.get_ticks_usec()-start
		costs.ticks += 1
	func _planned_speed() -> float:
		var start := Time.get_ticks_usec()
		var result := super._planned_speed()
		costs.planner += Time.get_ticks_usec()-start
		return result
	func _corner_speed(a: Vector3,b: Vector3,c: Vector3) -> float:
		var start := Time.get_ticks_usec()
		var result := super._corner_speed(a,b,c)
		costs.corner += Time.get_ticks_usec()-start
		return result
	func _update_index(p: Vector3) -> void:
		var start := Time.get_ticks_usec()
		super._update_index(p)
		costs.index += Time.get_ticks_usec()-start
	func _traffic_speed(speed: float) -> float:
		var start := Time.get_ticks_usec()
		var result := super._traffic_speed(speed)
		costs.traffic += Time.get_ticks_usec()-start
		return result

func _initialize() -> void:
	call_deferred("profile")

func profile() -> void:
	var soak := "--soak" in OS.get_cmdline_user_args()
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_seed = 1234
	root.add_child(main)
	var fixture = preload("res://tools/validate_racecraft.gd").new()
	if "--drive-player" in OS.get_cmdline_user_args():
		main.player.human_controlled = false
		var driver = preload("res://game/ai/oval_driver.gd").new()
		driver.name = "Driver"
		main.player.add_child(driver)
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/mile_oval/ai/race_line.json"))
		data.racing_corridor = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/mile_oval/ai/racing_corridor.json"))
		driver.configure(main.player,data,0)
		driver.rivals.assign(main.ai_cars)
		fixture.place(main.player,60,0,65)
	for i in range(main.ai_cars.size()):
		var car = main.ai_cars[i]
		var saved := {}
		for property in car.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.name not in ["engine_rpm","gear_text"]:
				saved[property.name] = car.get(property.name)
		car.set_script(TimedCar)
		for key in saved:
			car.set(key,saved[key])
		var model := TimedModel.new()
		for property in car.sim.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				model.set(property.name,car.sim.get(property.name))
		car.sim = model
		var old = car.get_node("Driver")
		var driver := TimedDriver.new()
		for property in old.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				driver.set(property.name,old.get(property.name))
		car.remove_child(old)
		old.free()
		driver.name = "Driver"
		car.add_child(driver)
		fixture.place(car,100+i*16,0,65)
	var results: Array = []
	for view in (["cockpit"] if soak or "--cockpit" in OS.get_cmdline_user_args() else ["external","cockpit"]):
		var cockpit = main.get_node("DisplayCar/Cockpit")
		if view == "external":
			cockpit.deactivate()
			main.get_node("InspectionCamera").followed_ai = 0
			main.get_node("InspectionCamera").make_current()
		else:
			cockpit.activate()
		var start := Time.get_ticks_usec()
		var last := start
		var frames: Array[float] = []
		var window_frames: Array[float] = []
		var next_report := start+60000000
		var engine_ms := 0.0
		for car in main.ai_cars:
			for key in car.movement_costs:
				car.movement_costs[key] = 0
			car.sim.integration_usec = 0
			var costs: Dictionary = car.get_node("Driver").costs
			for key in costs:
				costs[key] = 0
		while Time.get_ticks_usec()-start < (180000000 if soak else 30000000):
			await process_frame
			var now := Time.get_ticks_usec()
			if not soak or now-start >= 2000000:
				frames.append((now-last)/1000.0)
				window_frames.append((now-last)/1000.0)
				engine_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
			last = now
			if soak and now >= next_report:
				window_frames.sort()
				print("COCKPIT SOAK seconds=%.0f median=%.3f p95=%.3f p99=%.3f" % [(now-start)/1000000.0,window_frames[window_frames.size()/2],window_frames[int(window_frames.size()*.95)],window_frames[int(window_frames.size()*.99)]])
				window_frames.clear()
				next_report += 60000000
		var sum_ms := 0.0
		for ms in frames:
			sum_ms += ms
		var item := {"view":view,"mean_frame_ms":sum_ms/frames.size(),"engine_physics_ms":engine_ms/frames.size()}
		frames.sort()
		item.median_ms = frames[frames.size()/2]
		item.p95_ms = frames[int(frames.size()*.95)]
		item.p99_ms = frames[int(frames.size()*.99)]
		for key in ["driver","planner","corner","index","traffic"]:
			var total := 0.0
			for car in main.ai_cars:
				var costs: Dictionary = car.get_node("Driver").costs
				total += float(costs[key])/maxi(1,costs.ticks)/1000.0
			item[key+"_ms"] = total
		for key in ["movement","step","zones","integration"]:
			var total := 0.0
			for car in main.ai_cars:
				var value: int = car.sim.integration_usec if key == "integration" else car.movement_costs[key]
				total += float(value)/maxi(1,car.movement_costs.ticks)/1000.0
			item[key+"_ms"] = total
		print(JSON.stringify(item))
		results.append(item)
	var output := FileAccess.open("res://builds/ai_costs_driving_soak.json" if soak else "res://builds/ai_costs.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(results,"  "))
	output.close()
	fixture.free()
	quit()
