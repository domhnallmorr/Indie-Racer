extends SceneTree
var failures: Array[String] = []
var hz := 120

func _initialize() -> void:
    call_deferred("run")

func height(x: float, z: float) -> float:
    if x < -1.0 or x > -.4 or z > -5 or z < -7: return 0.0
    return .015*(1-cos(TAU*(-z-5)/2))

func run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
    Engine.physics_ticks_per_second = hz
    # Collision movement and model integration must use the same delta.
    Engine.time_scale = 1
    root.set_meta("roster_selection",{"track_id":"indianapolis","session_mode":"private_testing","seed":123})
    var main = load("res://game/main/main.tscn").instantiate()
    main.ai_enabled = false
    root.add_child(main)
    await process_frame
    var car = main.player
    car.set_physics_process(false)
    var terrain := StaticBody3D.new()
    terrain.collision_layer = 1
    terrain.position = Vector3(0,50,0)
    terrain.set_meta("drivable_surface",true)
    var vertices := PackedVector3Array()
    var xs := [-4.0,-1.1,-.95,-.45,-.3,4.0]
    for j in range(260):
        var z0 := 5.0-j*.1
        var z1 := z0-.1
        for i in range(xs.size()-1):
            var a := Vector3(xs[i],height(xs[i],z0),z0)
            var b := Vector3(xs[i+1],height(xs[i+1],z0),z0)
            var c := Vector3(xs[i],height(xs[i],z1),z1)
            var d := Vector3(xs[i+1],height(xs[i+1],z1),z1)
            vertices.append_array(PackedVector3Array([a,b,c,b,d,c]))
    var shape := ConcavePolygonShape3D.new()
    shape.backface_collision = true
    shape.set_faces(vertices)
    var collision := CollisionShape3D.new()
    collision.shape = shape
    terrain.add_child(collision)
    root.add_child(terrain)
    await physics_frame
    var fixture_hit := root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,50.5,0),Vector3(0,49.5,0),1))
    if fixture_hit.is_empty() or fixture_hit.normal.y < .99:
        failures.append("Fixture must provide upward-facing collision")
    car.reset_dynamics()
    car.global_transform = Transform3D(Basis.IDENTITY,Vector3(0,50.02,0))
    car.player_state.pit_stall_state = car.player_state.StallState.NONE
    car.sim.gear = 0
    for i in range(hz):
        await physics_frame
        car.drive_step(1.0/hz,0,1,0)
    car.sim.u = 10
    car.sim.front_omega = 10/car.sim.p.front_radius_m
    car.sim.rear_omega = 10/car.sim.p.rear_radius_m
    var peak_wheel_load := 0.0
    var no_support_s := 0.0
    var peak_roll := 0.0
    var peak_asymmetry := 0.0
    var peak_heave := 0.0
    var peak_left_road := 0.0
    var peak_right_road := 0.0
    for frame in range(3*hz):
        await physics_frame
        car.drive_step(1.0/hz,0,0,0)
        for load_n in car.sim.wheel_loads: peak_wheel_load = maxf(peak_wheel_load,load_n)
        if not car.sim.suspension.has_support(): no_support_s += 1.0/hz
        peak_roll = maxf(peak_roll,absf(car.sim.suspension.roll))
        peak_asymmetry = maxf(peak_asymmetry,absf(car.sim.wheel_loads[0]-car.sim.wheel_loads[1]))
        peak_heave = maxf(peak_heave,absf(car.sim.suspension.heave_velocity_mps))
        peak_left_road = maxf(peak_left_road,car.suspension_road_points[0].y-50)
        peak_right_road = maxf(peak_right_road,car.suspension_road_points[1].y-50)
        if not car.global_position.is_finite(): failures.append("Nonfinite bump-scene motion")
        if car.global_position.z < -17: break
    print("BUMP SCENE hz=",hz," peak_wheel_load_n=",peak_wheel_load," no_support_s=",no_support_s," roll_deg=",rad_to_deg(peak_roll)," axle_asymmetry_n=",peak_asymmetry," heave_mps=",peak_heave," road_left/right=",peak_left_road,"/",peak_right_road)
    if peak_left_road < .025 or peak_right_road > .001: failures.append("Fixture must excite left wheel only")
    if peak_roll < .001 or peak_asymmetry < 100 or peak_heave < .01: failures.append("Physical bump must excite body modes and unequal wheel loads")
    if absf(car.sim.suspension.heave_velocity_mps) > .05 or absf(car.sim.suspension.roll) > .005: failures.append("Bump response must settle")
    if car.floor_snap_length != 0: failures.append("Bump test must bypass floor snap")
    for failure in failures: push_error(failure)
    if failures.is_empty(): print("BUMP SCENE PASSED: physical ray samples, single-side road input, chassis heave/roll, tyre loading and settling.")
    quit(0 if failures.is_empty() else 1)
