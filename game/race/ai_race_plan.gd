extends RefCounted
## Seeded race-only fuel range and mechanical failures, shared by both AI drivers.
const RETIREMENT_CHANCE := 0.20
const OTHER_FAILURE_SHARE := 0.50
const LIMP_SPEED_KPH := 100.0
enum FailureType { ENGINE, OTHER }
const STOP_DWELL_SECONDS := 15.0
var extra_range_laps := 0
var failure_progress := INF
var failure_type := FailureType.ENGINE
var returning := false
var return_distance := 0.0
var retired := false
var recovered := false
var stopping_time := 0.0
var stopped_time := 0.0
var distance := 0.0
var initial_offset := Vector3.ZERO
var smoke: CPUParticles3D

func configure(driver, seed_value: int) -> void:
	var strategy_rng := RandomNumberGenerator.new()
	strategy_rng.seed = seed_value ^ 0x517A
	var draw := strategy_rng.randf()
	extra_range_laps = 0 if draw < .7 else (2 if draw < .9 else 3)
	var state = driver.car.player_state
	var nominal_range: float = state.fuel_capacity_gal/state.fuel_per_lap_gal
	state.fuel_per_lap_gal = state.fuel_capacity_gal/(nominal_range+extra_range_laps)
	var failure_rng := RandomNumberGenerator.new()
	failure_rng.seed = seed_value ^ 0xFA17
	if failure_rng.randf() < RETIREMENT_CHANCE:
		failure_progress = failure_rng.randf_range(.05,.95)*driver.practice_session.race_laps
	# Separate draw preserves existing failure incidence, timing and fuel plans.
	var type_rng := RandomNumberGenerator.new()
	type_rng.seed = seed_value ^ 0x07E2
	failure_type = FailureType.OTHER if type_rng.randf() < OTHER_FAILURE_SHARE else FailureType.ENGINE
	driver.car.set_meta("strategy_extra_laps",extra_range_laps)

func update(driver, delta: float) -> bool:
	if returning:
		_update_return(driver,delta)
		return true
	if not retired:
		if not is_finite(failure_progress) or driver.practice_session.status != driver.practice_session.Status.RUNNING or driver.mode != driver.Mode.RACING:
			return false
		var timing = driver.car.get_parent().get("lap_timing")
		for entry in timing.entries:
			if entry.car == driver.car and maxf(0.0,(timing._track_progress(entry)-1.0)/timing.gates.size()) >= failure_progress:
				fail(driver,failure_type)
				break
		if returning:
			_update_return(driver,delta)
			return true
		if not retired:
			return false
	if recovered:
		return true
	var car = driver.car
	if car.speed_mps > 0.0 or stopping_time < 3.0:
		stopping_time += delta
		var old_speed: float = car.speed_mps
		car.speed_mps = move_toward(old_speed,0.0,6.0*delta)
		distance += (old_speed+car.speed_mps)*.5*delta
		var at := fposmod(distance,driver.race_length_m)
		var point: Vector3 = driver._sample_path(driver.race,driver.race_distances,at)
		var ahead: Vector3 = driver._sample_path(driver.race,driver.race_distances,fposmod(at+2.0,driver.race_length_m))
		var right := (ahead-point).normalized().cross(Vector3.UP).normalized()
		var shoulder: Vector3 = point-right*13.0
		if driver.racecraft.enabled:
			shoulder = driver._sample_path(driver.racecraft.inner,driver.race_distances,at)-right*3.0
		var blend := smoothstep(0.0,3.0,stopping_time)
		# Also completes the pull-over for a failure at unusually low speed.
		var next: Vector3 = car.track.to_global((point+initial_offset).lerp(shoulder,blend))
		var query := PhysicsRayQueryParameters3D.create(next+Vector3.UP*6,next-Vector3.UP*12,1)
		var excluded: Array[RID] = [car.get_rid()]
		for rival in driver.rivals:
			excluded.append(rival.get_rid())
		query.exclude = excluded
		var hit: Dictionary = car.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			next.y = hit.position.y+.025
		var heading: Vector3 = next-car.global_position
		heading.y = 0.0
		if heading.length_squared() > .00001:
			car.global_basis = Basis.looking_at(heading.normalized(),Vector3.UP)
		car.global_position = next
		car.player_state.speed_mps = car.speed_mps
		if car.speed_mps == 0.0 and stopping_time >= 3.0:
			car.reset_dynamics()
	else:
		stopped_time += delta
		if stopped_time >= STOP_DWELL_SECONDS:
			car.global_transform = driver.pit_box_pose
			car.reset_dynamics()
			car.player_state.pit_stall_state = car.player_state.StallState.STOPPED
			car.update_zone_state()
			smoke.emitting = false
			recovered = true
	return true

func fail(driver, kind: FailureType = FailureType.ENGINE) -> void:
	if retired or returning:
		return
	failure_type = kind
	if kind == FailureType.OTHER:
		_begin_return(driver)
		return
	retired = true
	var car = driver.car
	car.set_meta("retired",true)
	car.set_meta("pit_ghost",true)
	driver.car_ghost = true
	car.collision_layer = 0
	car.collision_mask = 0
	car.player_state.set_engine_running(false)
	driver.service_started = -1.0
	var timing = car.get_parent().get("lap_timing")
	timing.retire(car,"Engine failure")
	var local: Vector3 = car.track.to_local(car.global_position)
	# Project onto the current segment to avoid jumping backwards on failure.
	var a: Vector3 = driver.race[driver.index]
	var b: Vector3 = driver.race[(driver.index+1)%driver.race.size()]
	var fraction := clampf((local-a).dot(b-a)/maxf(a.distance_squared_to(b),.001),0,1)
	distance = lerpf(driver.race_distances[driver.index],driver.race_distances[driver.index+1],fraction)
	initial_offset = local-a.lerp(b,fraction)
	_create_smoke(car)
	var control = driver.practice_session.race_control
	if control != null:
		control.call_caution("Engine failure: "+str(car.get_meta("driver_name",car.name)))

func failure_name() -> String:
	return "Other" if failure_type == FailureType.OTHER else "Engine failure"

func _begin_return(driver) -> void:
	returning = true
	return_distance = 0.0
	var car = driver.car
	car.set_meta("withdrawing",true)
	car.set_meta("pit_ghost",true)
	car.collision_layer = 0
	car.collision_mask = 0
	driver.service_started = -1.0
	# Allow enough road for the slowdown and lateral transition. A failure
	# immediately before pit entry takes another inside lap instead of diving in.
	var lane_speed: float = car.track_data.speed_limit_kph/3.6
	var approach := maxf(100.0,(car.speed_mps*car.speed_mps-lane_speed*lane_speed)/12.0+100.0)
	driver._begin_pit_entry(true,approach)

func _update_return(driver, delta: float) -> void:
	var car = driver.car
	var remaining: float = driver.route_distances[-1]-return_distance
	var lane_speed: float = car.track_data.speed_limit_kph/3.6
	var target := minf(LIMP_SPEED_KPH/3.6,sqrt(2.0*3.0*maxf(0.0,remaining)))
	target = minf(target,sqrt(lane_speed*lane_speed+12.0*maxf(0.0,driver.pit_entry_lane_distance-return_distance-10.0)))
	if remaining < 40.0:
		target = minf(target,8.0)
	var old_speed: float = car.speed_mps
	car.speed_mps = move_toward(old_speed,target,6.0*delta)
	var travelled := minf(remaining,(old_speed+car.speed_mps)*.5*delta)
	return_distance += travelled
	var next: Vector3 = car.track.to_global(driver._sample_path(driver.route,driver.route_distances,return_distance))
	var query := PhysicsRayQueryParameters3D.create(next+Vector3.UP*6,next-Vector3.UP*12,1)
	var excluded: Array[RID] = [car.get_rid()]
	for rival in driver.rivals:
		excluded.append(rival.get_rid())
	query.exclude = excluded
	var hit: Dictionary = car.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		next.y = hit.position.y+.025
	var heading: Vector3 = next-car.global_position
	heading.y = 0.0
	if heading.length_squared() > .00001:
		car.global_basis = Basis.looking_at(heading.normalized(),Vector3.UP)
	car.global_position = next
	car.player_state.speed_mps = car.speed_mps
	car.player_state.consume_distance(travelled)
	car.update_zone_state()
	car._update_visual_grounding(delta)
	if remaining-travelled <= .02:
		car.global_transform = driver.pit_box_pose
		car.reset_dynamics()
		car.player_state.speed_mps = 0.0
		car.player_state.set_engine_running(false)
		car.player_state.pit_stall_state = car.player_state.StallState.STOPPED
		car.update_zone_state()
		driver.mode = driver.Mode.WAITING
		returning = false
		retired = true
		recovered = true
		car.set_meta("withdrawing",false)
		car.set_meta("retired",true)
		car.get_parent().lap_timing.retire(car,"Other")

func _create_smoke(car: Node3D) -> void:
	smoke = CPUParticles3D.new()
	smoke.name = "EngineFailureSmoke"
	smoke.position = Vector3(0,.8,1.5)
	smoke.local_coords = false
	smoke.amount = 90
	smoke.lifetime = 3.0
	smoke.direction = Vector3(0,1,.3)
	smoke.spread = 35
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 2.5
	smoke.gravity = Vector3(0,.6,0)
	smoke.scale_amount_min = .5
	smoke.scale_amount_max = 1.2
	var growth := Curve.new()
	growth.add_point(Vector2(0,.25))
	growth.add_point(Vector2(1,2.0))
	smoke.scale_amount_curve = growth
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0,.15,1.0])
	fade.colors = PackedColorArray([Color(.45,.45,.48,0),Color(.45,.45,.48,.55),Color(.65,.65,.67,0)])
	smoke.color_ramp = fade
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2.2,2.2)
	var material := ShaderMaterial.new()
	material.shader = preload("res://game/race/engine_smoke.gdshader")
	mesh.material = material
	smoke.mesh = mesh
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	car.add_child(smoke)
	smoke.emitting = true
