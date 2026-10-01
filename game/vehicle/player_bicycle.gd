extends "res://game/vehicle/basic_car.gd"
const Config = preload("res://game/vehicle/physics_config.gd")
const Model = preload("res://game/vehicle/bicycle_model.gd")
const Gearing = preload("res://game/vehicle/gearing_setup.gd")
const Slipstream = preload("res://game/vehicle/slipstream.gd")
@export var slipstream_enabled := true
@export_dir var physics_directory := "res://content/vehicles/open_wheel/physics"
@export var human_controlled := true
var physics_components: Dictionary = {}
var sim = Model.new()
var parameters = Config.new()
var physics_ready := false
var surface_name := "tarmac"
var wheel_input: Node
var telemetry = preload("res://game/vehicle/telemetry.gd").new()
var aero_setup_key := ""
var gearing_setup_key := ""
@export var wind_world_mps := Vector3.ZERO

func load_gearing_setup(track_key: String) -> void:
	gearing_setup_key = track_key
	# Provisional Texas baseline, retaining the authored gear spacing.
	if track_key.get_base_dir().get_file() == "texas":
		sim.p.final_drive = 3.40
	var saved := ConfigFile.new()
	if saved.load("user://gearing_setups.cfg") != OK:
		return
	var final_drive = saved.get_value(track_key,"final_drive",sim.p.final_drive)
	var ratios = saved.get_value(track_key,"forward_ratios",sim.p.forward_ratios)
	if Gearing.valid(final_drive,ratios):
		sim.p.final_drive = float(final_drive)
		sim.p.forward_ratios = ratios.duplicate()

func save_gearing_setup(final_drive: float, ratios: Array) -> Error:
	if not can_adjust_aero() or gearing_setup_key.is_empty():
		return ERR_UNAVAILABLE
	if not Gearing.valid(final_drive,ratios):
		return ERR_INVALID_PARAMETER
	var saved := ConfigFile.new()
	var error := saved.load("user://gearing_setups.cfg")
	if error != OK and error != ERR_FILE_NOT_FOUND:
		return error
	saved.set_value(gearing_setup_key,"final_drive",final_drive)
	saved.set_value(gearing_setup_key,"forward_ratios",ratios)
	error = saved.save("user://gearing_setups.cfg")
	if error == OK:
		sim.p.final_drive = final_drive
		sim.p.forward_ratios = ratios.duplicate()
		# Ratio changes are only permitted parked; discard clutch/axle history.
		sim.reset()
	return error

func load_aero_setup(track_key: String) -> void:
	aero_setup_key = track_key
	var saved := ConfigFile.new()
	if saved.load("user://aero_setups.cfg") != OK:
		return
	var package = saved.get_value(track_key,"body_package",sim.p.body_package)
	var front = saved.get_value(track_key,"front_wing_deg",sim.p.front_wing_deg)
	var rear = saved.get_value(track_key,"rear_wing_deg",sim.p.rear_wing_deg)
	if package not in ["road","speedway"] or not (front is float or front is int) or not (rear is float or rear is int):
		return
	if not is_finite(float(front)) or not is_finite(float(rear)) or front < 3 or front > 18 or rear < 3 or rear > 18:
		return
	preload("res://game/vehicle/aero_model.gd").apply(sim.p,package,front,rear)

func can_adjust_aero() -> bool:
	return physics_ready and player_state != null and player_state.session != null and player_state.session.session_type in [player_state.session.SessionType.PRACTICE,player_state.session.SessionType.QUALIFYING] and player_state.pit_stall_state == player_state.StallState.STOPPED and Vector2(sim.u,sim.v).length() < 0.5

func save_aero_setup(package: String, front: float, rear: float) -> Error:
	if not can_adjust_aero() or aero_setup_key.is_empty():
		return ERR_UNAVAILABLE
	if package not in ["road","speedway"] or not is_finite(front) or not is_finite(rear) or front < 3 or front > 18 or rear < 3 or rear > 18:
		return ERR_INVALID_PARAMETER
	var saved := ConfigFile.new()
	var read_error := saved.load("user://aero_setups.cfg")
	if read_error != OK and read_error != ERR_FILE_NOT_FOUND:
		return read_error
	saved.set_value(aero_setup_key,"body_package",package)
	saved.set_value(aero_setup_key,"front_wing_deg",front)
	saved.set_value(aero_setup_key,"rear_wing_deg",rear)
	var error := saved.save("user://aero_setups.cfg")
	if error == OK:
		preload("res://game/vehicle/aero_model.gd").apply(sim.p,package,front,rear)
	return error

func _exit_tree() -> void:
	telemetry.stop()

func slipstream_forward_speed() -> float:
	return sim.u

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
	add_to_group(Slipstream.GROUP)
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
	sim.slipstream_target = Slipstream.sample(self)
	var normal := get_floor_normal() if is_on_floor() else Vector3.UP
	if normal.length_squared() < .5:
		normal = Vector3.UP
	var forward := (-global_basis.z).slide(normal).normalized()
	var left := normal.cross(forward).normalized()
	sim.wind_body_mps = Vector2(wind_world_mps.dot(forward),wind_world_mps.dot(left))
	# The model's heading change is a rotation about world up. Its normal
	# acceleration supplies the extra tyre load when turning into banking.
	sim.turn_normal_factors = Vector2(Vector3.UP.cross(forward).dot(normal),Vector3.UP.cross(left).dot(normal))
	var gravity := Vector3.DOWN*9.81
	var grip: float = _surface_grip()*player_state.tyre_grip_multiplier()
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
	if not hit_static_wall and not car_contact_this_step and get_slide_collision_count() > 0 and travelled.length() < expected*.5:
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

func _contact_mass_kg() -> float:
	return sim.vehicle_mass_kg

func reset_dynamics() -> void:
	_reset_wall_contacts()
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
