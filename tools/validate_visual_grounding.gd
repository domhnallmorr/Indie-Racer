extends SceneTree
const DT := 1.0/60.0
var failed := false

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var main = load("res://game/main/main.tscn").instantiate()
	main.roster_file = "res://content/rosters/icr2_test/manifest.json"
	root.add_child(main)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.get_node("MileOval").process_mode = Node.PROCESS_MODE_ALWAYS
	for car in [main.player]+main.ai_cars:
		car.process_mode = Node.PROCESS_MODE_ALWAYS
		car.set_physics_process(false)
		if car.has_node("Driver"):
			car.get_node("Driver").set_physics_process(false)
	await physics_frame
	var excluded: Array[RID] = [main.player.get_rid()]
	for car in main.ai_cars:
		excluded.append(car.get_rid())
	var track = main.get_node("MileOval")
	var camera: Camera3D
	if "--capture" in OS.get_cmdline_user_args():
		main.get_node("HUD").hide()
		camera = Camera3D.new()
		main.add_child(camera)
		camera.near = .05
		camera.far = 1500
		camera.fov = 48
		camera.cull_mask = 3
		camera.make_current()
	var cases := [
		["flat",Vector3(0,0,129),-PI*.5],
		["east_bank",Vector3(330.986459,10*tan(deg_to_rad(9)),0),0.0],
		["west_bank",Vector3(-330.986459,10*tan(deg_to_rad(9)),0),PI],
		["bank_entry",Vector3(205.986459+125*sin(.4),10*tan(deg_to_rad(4.5)),125*cos(.4)),-PI*.5+.4],
	]
	for car in [main.ai_cars[0],main.player]:
		car.set_physics_process(false)
		for item in cases:
			car.reset_dynamics()
			car.global_transform = track.global_transform*Transform3D(Basis(Vector3.UP,item[2]),item[1]+Vector3.UP*.5)
			car.get_node("Visual").transform = Transform3D.IDENTITY
			for step in range(60):
				await physics_frame
				car.velocity = Vector3.DOWN*3
				car._move_with_car_contacts(DT)
				if car.has_method("_update_visual_grounding"):
					car._update_visual_grounding(DT)
				elif car.is_on_floor():
					var n: Vector3 = car.global_basis.inverse()*car.get_floor_normal()
					var r := n.cross(Vector3.BACK).normalized()
					car.get_node("Visual").basis = car.get_node("Visual").basis.slerp(Basis(r,n,r.cross(n)).orthonormalized(),DT*10)
			var worst := 0.0
			for contact in car.get_node("Visual").get_meta("tyre_contacts"):
				var bottom: Vector3 = car.get_node("Visual").to_global(contact)
				var ray := PhysicsRayQueryParameters3D.create(bottom+Vector3.UP,bottom-Vector3.UP*2)
				ray.exclude = excluded
				var hit = car.get_world_3d().direct_space_state.intersect_ray(ray)
				assert(not hit.is_empty())
				worst = maxf(worst,absf(bottom.y-hit.position.y))
			print("GROUNDING %s %s max tyre gap=%.4f m" % [car.name,item[0],worst])
			if worst > .035:
				failed = true
			if camera != null and item[0] == "east_bank":
				camera.global_position = car.global_position+Vector3(-7,1.2,-5)
				camera.look_at(car.get_node("Visual").global_position+Vector3.UP*.35)
				for frame in range(4):
					await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://builds/grounding_%s.png" % car.name)
			if car.has_node("Cockpit") and car.has_method("_update_visual_grounding"):
				var expected: Transform3D = car.get_node("Visual").transform*Transform3D(Basis.IDENTITY,car.get_node("Visual").get_meta("cockpit_offset",Vector3.ZERO))
				assert(car.get_node("Cockpit").transform.is_equal_approx(expected))
		# Sweep through entry/full bank/exit at 60 m/s, retaining the previous
		# visual pose at every step so this measures transition lag, not settling.
		var moving_gap := 0.0
		car.reset_dynamics()
		for step in range(430):
			var u := -18.0+step
			var a := clampf(u,0,PI*125.0)/125.0
			var t := clampf(minf(u,PI*125.0-u)/100.0,0,1)
			var bank := deg_to_rad(9.0*t*t*t*(10-15*t+6*t*t))
			var p := Vector3(205.986459+125*sin(a),10*tan(bank)+.35,125*cos(a))
			if u < 0:
				p.x += u
			elif u > PI*125:
				p.x -= u-PI*125
			car.global_transform = track.global_transform*Transform3D(Basis(Vector3.UP,-PI*.5+a),p)
			await physics_frame
			car.velocity = Vector3.DOWN*3
			car._move_with_car_contacts(DT)
			car._update_visual_grounding(DT)
			for contact in car.get_node("Visual").get_meta("tyre_contacts"):
				var bottom: Vector3 = car.get_node("Visual").to_global(contact)
				var ray := PhysicsRayQueryParameters3D.create(bottom+Vector3.UP,bottom-Vector3.UP*2)
				ray.exclude = excluded
				var hit = car.get_world_3d().direct_space_state.intersect_ray(ray)
				assert(not hit.is_empty())
				moving_gap = maxf(moving_gap,absf(bottom.y-hit.position.y))
		print("GROUNDING %s 60 m/s transition max gap=%.4f m" % [car.name,moving_gap])
		if moving_gap > .045:
			failed = true
		car.reset_dynamics()
		assert(car.get_node("Visual").position.y == 0)
		car.global_position += Vector3.UP*10
		await physics_frame
		car.velocity = Vector3.DOWN
		car._move_with_car_contacts(DT)
		var airborne_pose: Transform3D = car.get_node("Visual").transform
		car._update_visual_grounding(DT)
		assert(car.get_node("Visual").transform.is_equal_approx(airborne_pose),"Airborne visuals must not snap to road")
	quit(1 if failed else 0)

