extends SceneTree
## Exercise actual body sweeps and the following drive ticks, including track mesh walls.
var DT := 1.0/60.0
var hz := 60
var track_id := "mile_oval"
var failures: Array[String] = []
var events: Array[Dictionary] = []

func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
        if arg.begins_with("--track="): track_id = arg.trim_prefix("--track=")
    Engine.physics_ticks_per_second = hz
    Engine.time_scale = 1
    DT = 1.0/hz
    root.set_meta("roster_selection",{"track_id":track_id,"session_mode":"practice","file":"res://content/rosters/icr2_test/manifest.json","seed":123})
    print("CONTACT RATE track=",track_id," hz=",hz)
    call_deferred("validate")

func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)

func place(car, at: Vector3, motion: Vector3, heading := 0.0) -> void:
    car.reset_dynamics()
    car.global_position = at
    car.rotation = Vector3(0,heading,0)
    car._receive_contact_velocity(motion)
    if car.get("sim") != null:
        car.sim.front_omega = car.sim.u/car.parameters.values.front_radius_m
        car.sim.rear_omega = car.sim.u/car.parameters.values.rear_radius_m
        car.sim.gear = 3
        car.sim.engine_omega = maxf(car.sim.rear_omega*car.sim.ratio(),2500*TAU/60)

func step(car) -> void:
    if car.has_method("reference_step"):
        car.reference_step(DT,car.speed_mps,0)
    else:
        car.drive_step(DT,0,0,0)

func validate() -> void:
    var main = load("res://game/main/main.tscn").instantiate()
    main.roster_file = "res://content/rosters/icr2_test/manifest.json"
    root.add_child(main)
    main.process_mode = Node.PROCESS_MODE_DISABLED
    main.player.track.process_mode = Node.PROCESS_MODE_ALWAYS
    var cars: Array = [main.player,main.ai_cars[0]]
    for car in cars:
        car.process_mode = Node.PROCESS_MODE_ALWAYS
        car.set_physics_process(false)
        car.player_state.pit_stall_state = car.player_state.StallState.NONE
        car.player_state.set_engine_running(true)
        if car.has_node("Driver"):
            car.get_node("Driver").set_physics_process(false)
        car.wall_impact.connect(func(impact: Dictionary): events.append(impact))
        place(car,Vector3(50,100,1100),Vector3.ZERO)
    var arena := Node3D.new()
    root.add_child(arena)
    for spec in [[Vector3(500,1,500),Vector3(0,99.5,1000)], [Vector3(1,4,300),Vector3(0,101,1000)]]:
        var body := StaticBody3D.new()
        var shape := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = spec[0]
        shape.shape = box
        body.add_child(shape)
        arena.add_child(body)
        body.position = spec[1]
    for car in cars:
        for scenario in ["glancing", "head_on", "high_speed", "reverse", "gentle", "separating"]:
            events.clear()
            var motion := Vector3(10,0,-60)
            if scenario == "head_on": motion = Vector3(25,0,0)
            if scenario == "high_speed": motion = Vector3(90,0,0)
            if scenario == "reverse": motion = Vector3(10,0,25)
            if scenario == "gentle": motion = Vector3(.2,0,-10)
            if scenario == "separating": motion = Vector3(-5,0,-10)
            var frontal: bool = scenario in ["head_on","high_speed"]
            place(car,Vector3(0,100.02,1000),motion,-PI/2 if frontal else 0.0)
            var shape: CollisionShape3D = car.get_node("CollisionShape3D")
            var half: Vector3 = shape.shape.size*.5
            var right_extent: float = (shape.global_position-car.global_position).x+absf(shape.global_basis.x.x)*half.x+absf(shape.global_basis.z.x)*half.z
            # A .2 m/s sweep must reach the wall at every cadence.
            car.global_position.x = -.5-right_extent-(.2*DT*.25 if scenario == "gentle" else .01)
            # Let the physics server synchronize the teleported/rotated fixture.
            await physics_frame
            await physics_frame
            # Direct initial sweep makes the incoming impulse precisely measurable.
            car.velocity = motion
            car._move_with_car_contacts(DT)
            if scenario in ["gentle", "separating"]:
                check(events.is_empty(),scenario+" should not report a damaging impact")
                if scenario == "gentle":
                    check(car.velocity.x < 0.0,"Gentle contact still separates below reporting threshold")
                continue
            check(events.size() == 1,scenario+" emits one impact per wall, not floor/triangle")
            check(car.velocity.x < -1,scenario+" rebounds away from wall")
            if scenario == "glancing":
                check(absf(car.velocity.z) > 55,"Glancing contact preserves tangential momentum")
            if not events.is_empty():
                var impact := events[0]
                check(absf(impact.closing_speed_mps-motion.x) < .05,"Severity uses normal closing speed")
                check(absf(impact.normal_energy_j-.5*car._contact_mass_kg()*motion.x*motion.x) < 1,"Impact energy includes configured mass and fuel")
                check(impact.normal.x < -.99 and impact.collider_id != 0,"Impact includes wall and outward normal")
            var contact_x: float = car.position.x
            for tick in range(roundi(12*hz/60.0)):
                await physics_frame
                step(car)
            check(car.position.x < contact_x-.05,scenario+" remains separated through subsequent drive steps")
            check(car.position.x < -1.4,scenario+" does not tunnel through wall")
            print("WALL ",car.name," ",scenario," events=",events.size()," velocity=",car.velocity)
        place(car,Vector3(50,100,1100),Vector3.ZERO)
    # Real outer wall: a straight mesh section and the banked curved section.
    var player = main.player
    # Both faces of each authored barrier must be solid at the near surface.
    for wall_z in [135.5,87.0,108.0]:
        for side in [-1.0,1.0]:
            var ray := PhysicsRayQueryParameters3D.create(
                player.track.to_global(Vector3(0,.3,wall_z+side*2)),
                player.track.to_global(Vector3(0,.3,wall_z-side*2)))
            var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(ray)
            check(not hit.is_empty(),"Wall face exists at "+str(wall_z))
            if not hit.is_empty():
                check(absf(player.track.to_local(hit.position).z-(wall_z+side*.25)) < .01,"Wall winding exposes the near face at "+str(wall_z))
    for banked in [false,true]:
        events.clear()
        place(player,player.track.to_global(Vector3(330,2,0) if banked else Vector3(0,.03,130)),Vector3.ZERO)
        for tick in range(roundi(20*hz/60.0)):
            await physics_frame
            step(player)
        player.rotation.y = -PI/2 if banked else PI
        player._receive_contact_velocity(Vector3(15,0,-5) if banked else Vector3(5,0,15))
        var bounced := false
        for tick in range(roundi(120*hz/60.0)):
            await physics_frame
            step(player)
            if not player.wall_impact_this_step.is_empty():
                bounced = player.velocity.dot(player.wall_impact_this_step.normal) > .1
                break
        check(bounced,"Real outer wall rebounds, banked="+str(banked))
        check(not events.is_empty(),"Real outer wall reports impact, banked="+str(banked))
        var impact_position: Vector3 = player.global_position
        var away: Vector3 = player.last_wall_impact.get("normal",Vector3.ZERO)
        for tick in range(roundi(15*hz/60.0)):
            await physics_frame
            step(player)
        check((player.global_position-impact_position).dot(away) > .05,"Real outer wall separates after impact, banked="+str(banked))
        print("TRACK WALL banked=",banked," events=",events.size()," position=",player.position)
    player.reset_dynamics()
    check(player.last_wall_impact.is_empty() and player.wall_impact_this_step.is_empty(),"Reset clears impact state")
    main.free()
    arena.free()
    for failure in failures:
        push_error(failure)
    print("WALL CONTACTS PASSED" if failures.is_empty() else "WALL CONTACTS FAILED")
    quit(0 if failures.is_empty() else 1)
