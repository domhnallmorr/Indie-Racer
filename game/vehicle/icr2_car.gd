extends "res://game/vehicle/basic_car.gd"
## Reference-trajectory AI movement. No bicycle/tyre integration.
var human_controlled := false
var physics_components: Dictionary = {}
var parameters = preload("res://game/vehicle/physics_config.gd").new()
var physics_ready := false
var acceleration_limit := 8.0
var braking_limit := 18.0

func _ready() -> void:
	super._ready()
	physics_ready = parameters.load_components(physics_components)
	floor_constant_speed = false

func _physics_process(_delta: float) -> void:
	pass # The route driver owns movement.

func reference_step(delta: float, target_speed: float, curvature: float) -> void:
	update_zone_state()
	if player_state.is_in_pit_speed_zone:
		target_speed = minf(target_speed, track_data.speed_limit_kph/3.6)
	speed_mps = move_toward(speed_mps, maxf(0,target_speed), (acceleration_limit if target_speed > speed_mps else braking_limit)*delta)
	# A simple kinematic envelope, including the banked oval's high-speed demand.
	var yaw_limit := minf(1.6,65.0/maxf(speed_mps,1.0))
	rotate_y(clampf(curvature*speed_mps,-yaw_limit,yaw_limit)*delta)
	var normal := get_floor_normal() if is_on_floor() else Vector3.UP
	var forward := (-global_basis.z).slide(normal).normalized()
	var fall := velocity.y-9.81*delta
	contact_drift = contact_drift.move_toward(Vector3.ZERO,4.0*delta)
	velocity = forward*speed_mps+contact_drift
	if not is_on_floor():
		velocity.y = fall
	var previous := global_position
	var hit_static_wall := _move_with_car_contacts(delta)
	var travelled := (global_position-previous)/maxf(delta,.0001)
	if hit_static_wall or (not car_contact_this_step and get_slide_collision_count() > 0 and travelled.length() < absf(speed_mps)*.5):
		speed_mps = maxf(0,travelled.dot(forward))
		contact_drift = Vector3.ZERO
	update_zone_state()
	if player_state.is_in_pit_speed_zone:
		speed_mps = minf(speed_mps,track_data.speed_limit_kph/3.6)
	player_state.speed_mps = speed_mps
	player_state.consume_distance(Vector2(travelled.x,travelled.z).length()*delta)
	_update_visual_grounding(delta)

func reset_dynamics() -> void:
	_reset_visual_grounding()
	speed_mps = 0
	velocity = Vector3.ZERO
	contact_drift = Vector3.ZERO
	contact_partners.clear()
