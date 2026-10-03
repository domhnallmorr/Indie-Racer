extends RefCounted
## First-pass tow tuning; distances are between vehicle origins, in metres.
const GROUP := &"slipstream_cars"
const MAX_DRAG_REDUCTION := 0.09
const WAKE_LENGTH_M := 75.0
const BUILD_TIME_S := 0.35
const RELEASE_TIME_S := 0.25
const MAX_FRONT_DOWNFORCE_LOSS := 0.20
const MAX_REAR_DOWNFORCE_LOSS := 0.10

static func strength(follower: Transform3D, follower_speed: float, leader: Transform3D, leader_speed: float, dirty_air := false) -> float:
	var speed_factor := smoothstep(20.0,45.0,minf(follower_speed,leader_speed))
	if speed_factor <= 0.0:
		return 0.0
	var forward := -leader.basis.z.normalized()
	var alignment := (-follower.basis.z.normalized()).dot(forward)
	if alignment <= 0.85:
		return 0.0
	var offset := follower.origin-leader.origin
	var behind := -offset.dot(forward)
	if behind <= (0.0 if dirty_air else 4.5) or behind >= WAKE_LENGTH_M:
		return 0.0
	var lateral := absf(offset.dot(leader.basis.x.normalized()))
	var height := absf(offset.dot(leader.basis.y.normalized()))
	var half_width := 1.6+behind*0.015
	var longitudinal := smoothstep(4.5,7.0,behind)*(1.0-smoothstep(10.0,WAKE_LENGTH_M,behind))
	# Keep the downforce penalty at the gearbox; only the tow fades near contact.
	if dirty_air:
		longitudinal = 1.0-smoothstep(10.0,WAKE_LENGTH_M,behind)
	return longitudinal*(1.0-smoothstep(0.0,half_width,lateral))*(1.0-smoothstep(1.0,3.0,height))*smoothstep(0.85,0.98,alignment)*speed_factor

static func eligible(car) -> bool:
	return car.physics_ready and car.slipstream_enabled and car.collision_layer != 0 and not car.get_meta("retired",false) and not car.get_meta("pit_ghost",false) and car.player_state != null and not car.player_state.is_in_pit_lane and not car.player_state.is_in_pit_speed_zone

static func sample(car, dirty_air := false) -> float:
	if not eligible(car) or car.slipstream_forward_speed() <= 20.0:
		return 0.0
	var follower: Transform3D = car.global_transform
	var follower_speed: float = car.slipstream_forward_speed()
	var strongest := 0.0
	for other in car.get_tree().get_nodes_in_group(GROUP):
		if other == car or other.track != car.track:
			continue
		# Most of the field is outside the wake. Reject it before inspecting
		# retirement/pit state and physics properties on every observer's tick.
		if follower.origin.distance_squared_to(other.global_position) > WAKE_LENGTH_M*WAKE_LENGTH_M:
			continue
		if not eligible(other):
			continue
		strongest = maxf(strongest,strength(follower,follower_speed,other.global_transform,other.slipstream_forward_speed(),dirty_air))
	return strongest
