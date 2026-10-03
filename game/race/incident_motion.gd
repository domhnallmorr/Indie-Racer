extends RefCounted
## Scripted loss of control/coast, with collision-free recovery to the box.
var elapsed := 0.0
var dwell := 0.0
var distance := 0.0
var initial_offset := Vector3.ZERO
var recovered := false
var crashing := false
var started := false

func begin(car, control, crash: bool) -> void:
	crashing = crash
	started = true
	distance = control.position_of(car)
	initial_offset = car.track.to_local(car.global_position)-control.circuit.sample_baked(distance)
	car.collision_layer = 0
	car.collision_mask = 0
	car.set_meta("pit_ghost",true)

func update(car, control, box: Transform3D, delta: float) -> void:
	if recovered:
		return
	if car.speed_mps > 0.0 or elapsed < 3.0:
		elapsed += delta
		var old_speed: float = maxf(0.0,car.speed_mps)
		car.speed_mps = move_toward(old_speed,0.0,(18.0 if crashing else 6.0)*delta)
		distance += (old_speed+car.speed_mps)*.5*delta
		var at := fposmod(distance,control.length)
		var point: Vector3 = control.circuit.sample_baked(at)
		var ahead: Vector3 = control.circuit.sample_baked(fposmod(at+2.0,control.length))
		var forward := (ahead-point).normalized()
		# A spin finishes at the outside edge; mechanical failures pull inside.
		var edge: Vector3 = control.incident_edge(at,crashing)
		var next: Vector3 = car.track.to_global((point+initial_offset).lerp(edge,smoothstep(0.0,3.0,elapsed)))
		var query := PhysicsRayQueryParameters3D.create(next+Vector3.UP*8,next-Vector3.UP*16,1)
		var excluded: Array[RID] = [car.get_rid(),control.main.player.get_rid()]
		for rival in control.main.ai_cars:
			excluded.append(rival.get_rid())
		query.exclude = excluded
		var hit: Dictionary = car.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			next.y = hit.position.y+.025
		car.global_position = next
		var heading: Vector3 = car.track.global_basis*forward
		heading.y = 0.0
		if heading.length_squared() > .0001:
			car.global_basis = Basis.looking_at(heading.normalized())
			if crashing:
				car.rotate_y(smoothstep(0.0,3.0,elapsed)*PI*1.5)
		car.player_state.speed_mps = car.speed_mps
		car._update_visual_grounding(delta)
	else:
		dwell += delta
		if dwell >= 15.0:
			car.global_transform = box
			car.reset_dynamics()
			car.player_state.speed_mps = 0.0
			car.player_state.pit_stall_state = car.player_state.StallState.STOPPED
			car.update_zone_state()
			recovered = true
