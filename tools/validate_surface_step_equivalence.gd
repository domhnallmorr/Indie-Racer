extends SceneTree
## Compare the optimized step against the original four-candidate solver at
## every live AI pose. test_move is read-only; restore any successful legacy lift.
class ComparedCar extends "res://game/vehicle/icr2_car.gd":
	var comparisons := 0
	var differences := 0
	func _try_surface_step(motion: Vector3) -> void:
		var before := global_transform
		legacy_step(motion)
		var expected := global_transform
		global_transform = before
		super._try_surface_step(motion)
		comparisons += 1
		if not global_transform.is_equal_approx(expected):
			differences += 1
			push_error("Surface step mismatch at %s: expected %s, got %s" % [before.origin,expected.origin,global_position])
	func legacy_step(motion: Vector3) -> void:
		# The box cannot roll over a mesh edge like a tyre. Allow a small grounded
		# rise only when the full body has overhead/forward clearance and a floor landing.
		if not is_on_floor() or max_surface_step_m <= 0 or motion.length_squared() < .00000001:
			return
		if not test_move(global_transform, motion):
			return
		# A full-height lift can itself catch an internal triangle edge on banked
		# road even when a 2–5 cm step is clear. Try the smallest valid body sweep
		# first; every candidate still requires overhead, forward and landing room.
		for fraction in [1.0/6.0,1.0/3.0,2.0/3.0,1.0]:
			var height: float = max_surface_step_m*fraction
			var lift := Vector3.UP*height
			var clearance := KinematicCollision3D.new()
			if test_move(global_transform,lift,clearance,.001,false,8):
				# Turning the upright chassis on banking can put its downhill edge
				# slightly into the road before this lift. Permit that initial road
				# overlap only; a real overhead obstacle must still reject the step.
				var road_only := clearance.get_collision_count() > 0
				for hit in range(clearance.get_collision_count()):
					road_only = road_only and _is_drivable_mesh_edge(clearance.get_collider(hit),clearance.get_position(hit))
				if not road_only:
					continue
			var raised := global_transform
			raised.origin += lift
			if test_move(raised,motion,null,.001,true):
				continue
			var landing := raised
			landing.origin += motion
			var collision := KinematicCollision3D.new()
			if not test_move(landing,Vector3.DOWN*(height+.02),collision):
				continue
			if collision.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
				continue
			var rise := height+collision.get_travel().y
			if rise <= .001 or rise > max_surface_step_m:
				continue
			global_position.y += rise+.001
			return

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var track_id := "mile_oval"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--track="): track_id = argument.trim_prefix("--track=")
	root.set_meta("roster_selection",{"track_id":track_id,"file":"res://content/rosters/irl_2001/manifest.json","seed":1181179623,"session_mode":"race","race_laps":20})
	var main = load("res://game/main/main.tscn").instantiate()
	root.add_child(main)
	main.player.global_transform = main.player.track.global_transform*main.track_data.pit_box_transform()
	main.player.reset_dynamics()
	for car in main.ai_cars:
		var saved := {}
		for property in car.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				saved[property.name] = car.get(property.name)
		car.set_script(ComparedCar)
		for property in car.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and saved.has(property.name):
				car.set(property.name,saved[property.name])
	var green_tick := -1
	var mismatches := 0
	var completed := false
	for tick in range(12000):
		await physics_frame
		for car in main.ai_cars:
			mismatches += car.differences
		if mismatches > 0: break
		if main.session.status == main.session.Status.RUNNING:
			if green_tick < 0: green_tick = tick
			if tick-green_tick >= 3600:
				completed = true
				break
	var count := 0
	for car in main.ai_cars: count += car.comparisons
	print("SURFACE STEP EQUIVALENCE track=",track_id," comparisons=",count," mismatches=",mismatches," green=",green_tick)
	main.free()
	quit(0 if mismatches == 0 and completed and count > 72000 else 1)
