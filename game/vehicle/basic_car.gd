extends CharacterBody3D
## Starter kinematic handling in SI units. No tyre/suspension simulation yet.
@export var acceleration_mps2 := 8.0
@export var braking_mps2 := 18.0
@export var coasting_drag_mps2 := 1.5
@export var max_speed_kph := 280.0
@export var reverse_speed_kph := 20.0
@export var wheelbase_m := 2.82
@export_range(0.0, 0.2, 0.01) var max_surface_step_m := 0.15
var speed_mps := 0.0
var driving_enabled := false
var track_data
var track: Node3D
var player_state: Node
## Temporary equal-mass contact model shared by reference AI and bicycle cars.
const CAR_RESTITUTION := 0.35
var contact_drift := Vector3.ZERO
var contact_frame := -1
var contact_partners: Array[int] = []
var car_contact_this_step := false

func _ready() -> void:
	floor_snap_length = .8
	floor_max_angle = deg_to_rad(50)
	floor_constant_speed = true
	for mapping in [["drive_accelerate", KEY_W], ["drive_brake", KEY_S], ["drive_left", KEY_A], ["drive_right", KEY_D]]:
		if not InputMap.has_action(mapping[0]):
			InputMap.add_action(mapping[0])
			var key := InputEventKey.new()
			key.physical_keycode = mapping[1]
			InputMap.action_add_event(mapping[0], key)

func _physics_process(delta: float) -> void:
	if driving_enabled:
		drive_step(delta, Input.get_action_strength("drive_accelerate"), Input.get_action_strength("drive_brake"), Input.get_axis("drive_right", "drive_left"))

func update_zone_state() -> void:
	var local := track.to_local(global_position)
	player_state.set_in_pit_lane(track_data.contains_pit_lane(local))
	player_state.is_in_pit_speed_zone = track_data.contains_speed_limit_zone(local)

func drive_step(delta: float, throttle: float, brake: float, steering: float) -> void:
	update_zone_state()
	if brake > 0:
		if speed_mps > .1:
			speed_mps = move_toward(speed_mps, 0, braking_mps2 * brake * delta)
		else:
			speed_mps = move_toward(speed_mps, -reverse_speed_kph / 3.6, acceleration_mps2 * brake * delta)
	elif throttle > 0:
		speed_mps = move_toward(speed_mps, max_speed_kph / 3.6, (braking_mps2 if speed_mps < 0 else acceleration_mps2) * throttle * delta)
	else:
		speed_mps = move_toward(speed_mps, 0, coasting_drag_mps2 * delta)
	_apply_limit()
	# Reduce steering lock with speed so keyboard taps remain manageable.
	var lock := lerpf(28.0, 3.5, clampf(absf(speed_mps) / 55.0, 0, 1))
	var yaw_rate := speed_mps / wheelbase_m * tan(deg_to_rad(lock)) * steering
	rotate_y(yaw_rate * delta)
	var forward := -global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var direction := forward.slide(get_floor_normal()).normalized() if is_on_floor() else forward
	var fall_speed := minf(velocity.y, 0) - 24.0 * delta
	contact_drift = contact_drift.move_toward(Vector3.ZERO, 4.0 * delta)
	velocity = direction * speed_mps + contact_drift
	if not is_on_floor():
		velocity.y = fall_speed
	var previous_position := global_position
	var hit_static_wall := _move_with_car_contacts(delta)
	# A wall impact must remove forward speed rather than accumulating throttle.
	if hit_static_wall:
		speed_mps = velocity.dot(direction)
	if not car_contact_this_step and get_slide_collision_count() > 0:
		var travelled_speed := (global_position - previous_position).dot(direction) / maxf(delta, .0001)
		if absf(travelled_speed) < absf(speed_mps) * .5:
			speed_mps = travelled_speed
	update_zone_state()
	_apply_limit()
	player_state.speed_mps = speed_mps
	_update_visual_grounding(delta)

func _update_visual_grounding(delta: float) -> void:
	# The upright collision box rests on its uphill edge. Tilting the mesh alone
	# therefore leaves its tyres ~15 cm above a 9-degree bank. Fit the visual
	# contact plane to four road samples, without moving the physics body.
	if not is_on_floor():
		return
	var contacts: PackedVector3Array = $Visual.get_meta("tyre_contacts",PackedVector3Array([
		Vector3(-.825,0,-1.5),Vector3(-.825,0,1.5),
		Vector3(.825,0,-1.5),Vector3(.825,0,1.5)]))
	var points := PackedVector3Array()
	var space := get_world_3d().direct_space_state
	for contact in contacts:
		var at := to_global(contact)
		var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*.6,at-Vector3.UP*1.2)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		# A neighbour's chassis must never become the visual ground plane.
		while not hit.is_empty() and hit.collider is CharacterBody3D:
			var excluded := query.exclude
			excluded.append(hit.rid)
			query.exclude = excluded
			hit = space.intersect_ray(query)
		if hit.is_empty() or hit.normal.dot(Vector3.UP) < .65:
			return # Preserve the last pose if a tyre has no supporting road.
		points.append(to_local(hit.position))
	var across := (points[2]+points[3]-points[0]-points[1])*.5
	var rearward := (points[1]+points[3]-points[0]-points[2])*.5
	var normal := rearward.cross(across).normalized()
	if normal.y < .65:
		return
	var right := normal.cross(Vector3.BACK).normalized()
	var target := Basis(right,normal,right.cross(normal).normalized()).orthonormalized()
	$Visual.basis = $Visual.basis.slerp(target,1.0-exp(-40.0*delta)).orthonormalized()
	# Highest required support avoids sinking a tyre while the tilt catches up.
	var lift := -INF
	for i in range(contacts.size()):
		lift = maxf(lift,points[i].y-($Visual.basis*contacts[i]).y)
	$Visual.position.y = clampf(lift+.003,-.65,.35)
	if has_node("Cockpit"):
		var offset: Vector3 = $Visual.get_meta("cockpit_offset",Vector3.ZERO)
		$Cockpit.transform = $Visual.transform*Transform3D(Basis.IDENTITY,offset)

func _reset_visual_grounding() -> void:
	$Visual.basis = Basis.IDENTITY
	$Visual.position.y = 0.0
	if has_node("Cockpit"):
		$Cockpit.transform = Transform3D(Basis.IDENTITY,$Visual.get_meta("cockpit_offset",Vector3.ZERO))

func _receive_contact_velocity(new_velocity: Vector3) -> void:
	velocity = new_velocity
	var forward := -global_basis.z
	forward.y = 0
	forward = forward.normalized()
	speed_mps = new_velocity.dot(forward)
	contact_drift = Vector3(new_velocity.x,0,new_velocity.z)-forward*speed_mps
	if player_state != null:
		player_state.speed_mps = speed_mps

func _move_with_car_contacts(delta: float) -> bool:
	# CharacterBody sliding treats another car like an immovable wall. Resolve
	# the closing velocity between cars instead of adopting that zeroed speed.
	var incoming := velocity
	car_contact_this_step = false
	_try_surface_step(Vector3(velocity.x,0,velocity.z)*delta)
	move_and_slide()
	apply_floor_snap()
	var resolved := incoming
	var static_normals: Array[Vector3] = []
	var frame := Engine.get_physics_frames()
	if contact_frame != frame:
		contact_frame = frame
		contact_partners.clear()
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		# A single slide can contain both floor and wall/car contacts.
		for hit in range(collision.get_collision_count()):
			var other = collision.get_collider(hit)
			var normal := collision.get_normal(hit)
			if other == null or not other.has_method("_receive_contact_velocity"):
				if normal.dot(Vector3.UP) < cos(floor_max_angle):
					static_normals.append(normal)
				continue
			car_contact_this_step = true
			var id: int = other.get_instance_id()
			if id in contact_partners:
				continue
			# Keep the prototype response horizontal: wheel contact must not
			# launch cars vertically. Separating contacts receive no impulse.
			normal.y = 0
			if normal.length_squared() < .01:
				continue
			normal = normal.normalized()
			var other_velocity: Vector3 = other.velocity
			var closing := (resolved-other_velocity).dot(normal)
			if closing < 0:
				contact_partners.append(id)
				if other.contact_frame != frame:
					other.contact_frame = frame
					other.contact_partners.clear()
				other.contact_partners.append(get_instance_id())
				var impulse := normal*(-closing*(1.0+CAR_RESTITUTION)*.5)
				resolved += impulse
				other._receive_contact_velocity(other_velocity-impulse)
	if car_contact_this_step:
		for normal in static_normals:
			if resolved.dot(normal) < 0:
				resolved = resolved.slide(normal)
		_receive_contact_velocity(resolved)
	return not static_normals.is_empty()

func _try_surface_step(motion: Vector3) -> void:
	# The box cannot roll over a mesh edge like a tyre. Allow a small grounded
	# rise only when the full body has overhead/forward clearance and a floor landing.
	if not is_on_floor() or max_surface_step_m <= 0 or motion.length_squared() < .00000001:
		return
	if not test_move(global_transform, motion):
		return
	var lift := Vector3.UP * max_surface_step_m
	if test_move(global_transform, lift):
		return
	var raised := global_transform
	raised.origin += lift
	if test_move(raised, motion):
		return
	var landing := raised
	landing.origin += motion
	var collision := KinematicCollision3D.new()
	if not test_move(landing, Vector3.DOWN * (max_surface_step_m + .02), collision):
		return
	if collision.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
		return
	var rise := max_surface_step_m + collision.get_travel().y
	if rise <= .001 or rise > max_surface_step_m:
		return
	global_position.y += rise + .001

func _apply_limit() -> void:
	var cap: float = track_data.speed_limit_kph / 3.6 if player_state.is_in_pit_speed_zone else max_speed_kph / 3.6
	speed_mps = clampf(speed_mps, -minf(reverse_speed_kph / 3.6, cap), cap)
