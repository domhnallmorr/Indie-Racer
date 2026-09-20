extends "res://game/vehicle/basic_car.gd"
const Config = preload("res://game/vehicle/physics_config.gd")
const Model = preload("res://game/vehicle/bicycle_model.gd")
@export_dir var physics_directory := "res://content/vehicles/open_wheel/physics"
@export var human_controlled := true
var physics_components: Dictionary = {}
var sim = Model.new()
var parameters = Config.new()
var physics_ready := false
var surface_name := "tarmac"
var wheel_input: Node
var telemetry = preload("res://game/vehicle/telemetry.gd").new()

func _exit_tree() -> void:
	telemetry.stop()

func _input(event: InputEvent) -> void:
	if human_controlled and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11 and physics_ready:
		if telemetry.file != null:
			telemetry.stop()
		else:
			var error: Error = telemetry.start(self)
			if error != OK:
				push_error("Could not start telemetry: " + error_string(error))
		get_viewport().set_input_as_handled()
var engine_rpm: float:
	get: return sim.rpm() if physics_ready else 0.0
var gear_text: String:
	get: return "R" if sim.gear == -1 else ("N" if sim.gear == 0 else str(sim.gear))

func _ready() -> void:
	super._ready()
	physics_ready = parameters.load_directory(physics_directory) if physics_components.is_empty() else parameters.load_components(physics_components)
	if not physics_ready:
		push_error("Player physics configuration failed: "+"; ".join(parameters.errors))
		return
	sim.configure(parameters.values)
	max_surface_step_m = parameters.values.surface_step_m
	floor_constant_speed = false
	if human_controlled:
		wheel_input = preload("res://game/input/wheel_input.gd").new()
		wheel_input.player = self
		add_child(wheel_input)

func _physics_process(delta: float) -> void:
	if human_controlled and driving_enabled and physics_ready:
		var inputs: Vector3 = wheel_input.controls()
		drive_step(delta, inputs.x, inputs.y, inputs.z)

func drive_step(delta: float, throttle_input: float, brake_input: float, steering: float) -> void:
	if not physics_ready:
		return
	# The base chassis mass is dry; fuel adds to the dynamic model only for the
	# player while the AI fuel/strategy pass is still pending.
	sim.set_vehicle_mass(parameters.values.mass_kg+player_state.fuel_mass_kg())
	if not player_state.has_fuel():
		throttle_input = 0.0
	if human_controlled and player_state.session != null and player_state.session.race_control != null:
		var control = player_state.session.race_control
		if control.active() and not player_state.is_in_pit_lane:
			# Gentle longitudinal assistance enforces the yellow target while the
			# player retains steering and may brake harder at any time.
			var target: float = control.target_speed(self)
			if speed_mps > target:
				throttle_input = 0.0
				brake_input = maxf(brake_input,clampf((speed_mps-target)*.15,0,1))
	if player_state.pit_stall_state in [player_state.StallState.STOPPED,player_state.StallState.SERVICING]:
		throttle_input = 0.0
		brake_input = 1.0
		steering = 0.0
	update_zone_state()
	var normal := get_floor_normal() if is_on_floor() else Vector3.UP
	if normal.length_squared() < .5:
		normal = Vector3.UP
	var forward := (-global_basis.z).slide(normal).normalized()
	var left := normal.cross(forward).normalized()
	var gravity := Vector3.DOWN*9.81
	var grip := _surface_grip()
	var grounded := is_on_floor()
	var gravity_components := Vector3(gravity.dot(forward) if grounded else 0, gravity.dot(left) if grounded else 0, maxf(0,normal.dot(Vector3.UP))*9.81)
	var cap: float = track_data.speed_limit_kph/3.6 if player_state.is_in_pit_speed_zone else INF
	sim.advance(delta,throttle_input,brake_input,steering,gravity.dot(forward) if is_on_floor() else 0,
		gravity.dot(left) if is_on_floor() else 0,maxf(0,normal.dot(Vector3.UP))*9.81,is_on_floor(),grip,cap)
	rotate_y(sim.heading_change)
	forward = (-global_basis.z).slide(normal).normalized()
	left = normal.cross(forward).normalized()
	var vertical_fall := velocity.y-9.81*delta
	velocity = forward*sim.u+left*sim.v
	if not is_on_floor():
		velocity.y = vertical_fall
	var previous := global_position
	var expected := Vector2(sim.u,sim.v).length()
	var hit_static_wall := _move_with_car_contacts(delta)
	var travelled := (global_position-previous)/maxf(delta,.0001)
	if hit_static_wall or (not car_contact_this_step and get_slide_collision_count() > 0 and travelled.length() < expected*.5):
		sim.u = travelled.dot(forward)
		sim.v = travelled.dot(left)
		sim.yaw_rate *= .5
	update_zone_state()
	# Geographic re-entry must enforce the existing limiter immediately.
	if player_state.is_in_pit_speed_zone:
		var planar := Vector2(sim.u,sim.v).limit_length(track_data.speed_limit_kph/3.6)
		sim.u = planar.x
		sim.v = planar.y
	speed_mps = Vector2(sim.u,sim.v).length()*(-1.0 if sim.u < 0 else 1.0)
	player_state.speed_mps = speed_mps
	player_state.consume_distance(Vector2(travelled.x,travelled.z).length()*delta)
	telemetry.record(self, delta, Vector3(throttle_input, brake_input, steering), normal, gravity_components, grip, grounded, travelled)
	_update_visual_grounding(delta)

func _receive_contact_velocity(new_velocity: Vector3) -> void:
	velocity = new_velocity
	var normal := get_floor_normal() if is_on_floor() else Vector3.UP
	var forward := (-global_basis.z).slide(normal).normalized()
	var left := normal.cross(forward).normalized()
	sim.u = new_velocity.dot(forward)
	sim.v = new_velocity.dot(left)
	speed_mps = Vector2(sim.u,sim.v).length()*(-1.0 if sim.u < 0 else 1.0)
	if player_state != null:
		player_state.speed_mps = speed_mps

func _surface_grip() -> float:
	var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.3,global_position-Vector3.UP)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and String(hit.collider.get_parent().name).begins_with("Ground"):
		surface_name = "grass"
		return parameters.values.grass_grip_multiplier
	surface_name = "tarmac"
	return 1.0

func reset_dynamics() -> void:
	_reset_visual_grounding()
	sim.reset()
	speed_mps = 0
	velocity = Vector3.ZERO
	contact_drift = Vector3.ZERO
	contact_partners.clear()

func _unhandled_input(event: InputEvent) -> void:
	if player_state != null and player_state.pit_stall_state == player_state.StallState.STOPPED:
		return
	if not human_controlled or not physics_ready or not driving_enabled or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_M: sim.automatic = not sim.automatic
		KEY_E:
			sim.automatic = false
			sim.select_gear(mini(6,sim.gear+1))
		KEY_Q:
			sim.automatic = false
			sim.select_gear(maxi(-1,sim.gear-1))
		KEY_N: sim.select_gear(0)
		KEY_V: sim.select_gear(1 if sim.gear == -1 else -1)
