extends "res://game/vehicle/basic_car.gd"
const Config = preload("res://game/vehicle/physics_config.gd")
const Model = preload("res://game/vehicle/bicycle_model.gd")
const Gearing = preload("res://game/vehicle/gearing_setup.gd")
const Slipstream = preload("res://game/vehicle/slipstream.gd")
@export var slipstream_enabled := true
@export var dirty_air_enabled := true
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
var roll_setup_key := ""
var suspension_visual: Node3D
var suspension_normal := Vector3.UP
var suspension_road_points := PackedVector3Array([Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO])
var previous_suspension_points := PackedVector3Array()
var previous_suspension_present := PackedByteArray()
var previous_suspension_road_basis := Basis.IDENTITY
var suspension_collision_rest := Transform3D.IDENTITY
var suspension_collision_cached := false
var suspension_wheels: Array[Node3D] = []
var suspension_wheel_origins := PackedVector3Array()
@export var wind_world_mps := Vector3.ZERO

static func valid_roll_balance(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= .35 and value <= .65

func load_roll_setup(track_key: String) -> void:
	roll_setup_key = track_key
	var saved := ConfigFile.new()
	if saved.load("user://mechanical_setups.cfg") != OK:
		return
	var value = saved.get_value(track_key,"front_roll_stiffness_fraction",sim.p.front_roll_stiffness_fraction)
	if valid_roll_balance(value):
		sim.p.front_roll_stiffness_fraction = float(value)

func load_suspension_setup(track_key: String) -> void:
	sim.suspension.enabled = false
	sim.suspension.profile_id = "disabled"
	sim.suspension.reset()
	if human_controlled and track_key.get_base_dir().get_file() == "indianapolis":
		if not sim.suspension.configure_indy("res://content/vehicles/open_wheel/physics/indy_suspension.cfg"):
			push_error("Could not load Indianapolis suspension prototype")
			return
		var saved := ConfigFile.new()
		if saved.load("user://mechanical_setups.cfg") == OK:
			var active = saved.get_value(track_key,"dynamic_roll_pitch",true)
			if active is bool:
				sim.suspension.enabled = active
			var travel = saved.get_value(track_key,"wheel_travel",true)
			if travel is bool:
				sim.suspension.wheel_travel_enabled = travel
		# Keep grounded wheels in the road-aligned Visual frame. Only chassis
		# meshes and the cockpit receive the reduced body-mode rotation.
		if suspension_visual == null:
			suspension_visual = Node3D.new()
			suspension_visual.name = "SuspensionBody"
			$Visual.add_child(suspension_visual)
			for child in $Visual.get_children():
				if child != suspension_visual and child is Node3D and not child.name.begins_with("Wheel"):
					child.reparent(suspension_visual)
			for wheel_name in ["WheelFrontLeft","WheelFrontRight","WheelRearLeft","WheelRearRight"]:
				var wheel: Node3D = $Visual.find_child(wheel_name,true,false)
				suspension_wheels.append(wheel)
				suspension_wheel_origins.append(wheel.position)
	_update_support_mode()

func _suspension_owns_support() -> bool:
	return physics_ready and sim.suspension.enabled and sim.suspension.wheel_travel_enabled

func _update_support_mode() -> void:
	floor_snap_length = 0.0 if _suspension_owns_support() else .8
	previous_suspension_points.clear()
	previous_suspension_present.clear()
	previous_suspension_road_basis = _suspension_world_road_basis(suspension_normal)
	_update_suspension_collision()

func _update_suspension_collision() -> void:
	var collider: CollisionShape3D = $CollisionShape3D
	if not suspension_collision_cached:
		suspension_collision_rest = collider.transform
		suspension_collision_cached = true
	if _suspension_owns_support():
		# Keep the collision backstop parallel to the road. An upright box's
		# uphill edge otherwise lifts the body above the wheels on banking.
		# Its base remains at the body origin, preserving normal clearance;
		# the visual tyre-plane offset must not be applied to this collider.
		var local_normal := global_basis.inverse()*suspension_normal
		var right := local_normal.cross(Vector3.BACK).normalized()
		var road_basis := Basis(right,local_normal,right.cross(local_normal)).orthonormalized()
		collider.transform = Transform3D(road_basis,Vector3.ZERO)*suspension_collision_rest
	else:
		collider.transform = suspension_collision_rest

func _suspension_world_road_basis(normal: Vector3) -> Basis:
	var forward := (-global_basis.z).slide(normal).normalized()
	var right := forward.cross(normal).normalized()
	return Basis(right,normal,-forward).orthonormalized()

func _transport_suspension_body(from: Basis, to: Basis) -> void:
	# Preserve body-up and angular velocity in world space when the road/yaw
	# reference changes. Spinning the heading must not rotate bank tilt into
	# a new suspension pitch deflection.
	var pose := Basis(Vector3.RIGHT,sim.suspension.pitch)*Basis(Vector3.BACK,-sim.suspension.roll)
	var up := to.inverse()*from*pose.y
	var angular := to.inverse()*from*Vector3(sim.suspension.pitch_rate,0,-sim.suspension.roll_rate)
	sim.suspension.roll = asin(clampf(up.x,-1,1))
	sim.suspension.pitch = atan2(up.z,up.y)
	sim.suspension.roll_rate = -angular.z
	sim.suspension.pitch_rate = angular.x

func _sample_suspension_road(delta: float) -> void:
	var previous_world_normal := suspension_normal
	var points := PackedVector3Array()
	var normals := Vector3.ZERO
	var present := PackedByteArray([0,0,0,0])
	var contacts: PackedVector3Array = $Visual.get_meta("tyre_contacts")
	# Metadata order is FL, RL, FR, RR; solver order is FL, FR, RL, RR.
	var indices := [0,2,1,3]
	var forward := (-global_basis.z).slide(suspension_normal).normalized()
	var right := forward.cross(suspension_normal).normalized()
	for i in range(4):
		var local: Vector3 = contacts[indices[i]]
		var at := global_position+right*local.x-forward*local.z
		var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*.6,at-Vector3.UP*2.0,1)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var ok: bool = not hit.is_empty() and hit.normal.dot(Vector3.UP) >= cos(floor_max_angle) and not hit.collider is CharacterBody3D
		present[i] = int(ok)
		points.append(hit.position if ok else at-suspension_normal*sim.suspension.ride_height_m)
		if ok: normals += hit.normal
	if present.count(1) == 4:
		# Fit contact heights, which are continuous across a bank/apron seam.
		# Averaging facet normals instead jumps as each ray changes triangles.
		var across := (points[1]+points[3]-points[0]-points[2])*.5
		var rearward := (points[2]+points[3]-points[0]-points[1])*.5
		var fitted := rearward.cross(across).normalized()
		if fitted.dot(Vector3.UP) >= cos(floor_max_angle):
			suspension_normal = fitted
	elif not sim.suspension.initialized and normals.length_squared() > .01:
		suspension_normal = normals.normalized()
	elif not sim.suspension.initialized:
		suspension_normal = Vector3.UP
	sim.road_normal_acceleration = -velocity.slide(previous_world_normal).dot(suspension_normal-previous_world_normal)/delta if sim.suspension.initialized else 0.0
	var road_basis := _suspension_world_road_basis(suspension_normal)
	if sim.suspension.initialized:
		var old_roll: float = sim.suspension.roll
		var old_pitch: float = sim.suspension.pitch
		_transport_suspension_body(previous_suspension_road_basis,road_basis)
		sim.suspension.road_roll_rate = (sim.suspension.roll-old_roll)/delta
		sim.suspension.road_pitch_rate = (sim.suspension.pitch-old_pitch)/delta
	var gaps := PackedFloat64Array()
	var speeds := PackedFloat64Array()
	var mean_gap := 0.0
	var count := 0
	for i in range(4):
		var gap := (global_position-points[i]).dot(suspension_normal)
		gaps.append(gap)
		# A newly acquired surface has no valid velocity history.
		speeds.append((points[i]-previous_suspension_points[i]).dot(suspension_normal)/delta if previous_suspension_points.size() == 4 and previous_suspension_present[i] and present[i] else 0.0)
		if present[i]:
			mean_gap += gap
			count += 1
	if not sim.suspension.initialized:
		# Lift only a freshly placed car already near its road. A reset in midair
		# must fall normally instead of snapping down to a sampled surface.
		if count > 0 and mean_gap/count < sim.suspension.ride_height_m+.10:
			var lift: float = sim.suspension.ride_height_m-mean_gap/count
			global_position.y += lift/maxf(suspension_normal.y,.65)
			for i in range(4): gaps[i] += lift
		sim.suspension.initialized = true
	suspension_road_points = points
	previous_suspension_points = points.duplicate()
	previous_suspension_present = present.duplicate()
	previous_suspension_road_basis = road_basis
	sim.suspension.begin_frame(gaps,speeds,present)

func save_suspension_enabled(active: bool, travel: bool = true) -> Error:
	if not can_adjust_aero() or sim.suspension.profile_id == "disabled":
		return ERR_UNAVAILABLE
	var saved := ConfigFile.new()
	var error := saved.load("user://mechanical_setups.cfg")
	if error != OK and error != ERR_FILE_NOT_FOUND:
		return error
	saved.set_value(roll_setup_key,"dynamic_roll_pitch",active)
	saved.set_value(roll_setup_key,"wheel_travel",travel)
	error = saved.save("user://mechanical_setups.cfg")
	if error == OK:
		sim.suspension.enabled = active
		sim.suspension.wheel_travel_enabled = travel
		sim.reset()
		_update_support_mode()
	return error

func _update_visual_grounding(delta: float) -> void:
	if _suspension_owns_support():
		var local_normal := global_basis.inverse()*suspension_normal
		var right := local_normal.cross(Vector3.BACK).normalized()
		$Visual.basis = Basis(right,local_normal,right.cross(local_normal)).orthonormalized()
		$Visual.position = -local_normal*sim.suspension.ride_height_m
	else:
		super._update_visual_grounding(delta)
	if suspension_visual == null:
		return
	var pose := Basis(Vector3.RIGHT,sim.suspension.pitch)*Basis(Vector3.BACK,-sim.suspension.roll)
	var pivot := Vector3(0,sim.p.cg_height_m,0)
	suspension_visual.transform = Transform3D(pose,pivot-pose*pivot)
	for i in range(suspension_wheels.size()):
		var origin: Vector3 = suspension_wheel_origins[i]
		if _suspension_owns_support() and sim.suspension.sampled:
			var mounted := suspension_visual.transform*origin
			var road_y: float = $Visual.to_local(suspension_road_points[i]).y+origin.y
			# Zero delivered force is not a command to snap to full droop.
			# Follow any road within geometric reach even during damper unloading.
			origin.y = maxf(road_y,mounted.y-sim.suspension.rebound_travel_m) if sim.suspension.road_present[i] else mounted.y-sim.suspension.rebound_travel_m
		suspension_wheels[i].position = origin
	if has_node("Cockpit"):
		$Cockpit.transform = $Visual.transform*suspension_visual.transform*Transform3D(Basis.IDENTITY,$Visual.get_meta("cockpit_offset",Vector3.ZERO))

func _reset_visual_grounding() -> void:
	super._reset_visual_grounding()
	if suspension_visual != null:
		suspension_visual.transform = Transform3D.IDENTITY
	for i in range(suspension_wheels.size()):
		suspension_wheels[i].position = suspension_wheel_origins[i]
	previous_suspension_points.clear()
	previous_suspension_present.clear()
	previous_suspension_road_basis = _suspension_world_road_basis(Vector3.UP)
	suspension_normal = Vector3.UP

func save_roll_setup(front_fraction: float) -> Error:
	if not can_adjust_aero() or roll_setup_key.is_empty():
		return ERR_UNAVAILABLE
	if not valid_roll_balance(front_fraction):
		return ERR_INVALID_PARAMETER
	var saved := ConfigFile.new()
	var error := saved.load("user://mechanical_setups.cfg")
	if error != OK and error != ERR_FILE_NOT_FOUND:
		return error
	saved.set_value(roll_setup_key,"front_roll_stiffness_fraction",front_fraction)
	error = saved.save("user://mechanical_setups.cfg")
	if error == OK:
		sim.p.front_roll_stiffness_fraction = front_fraction
	return error

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
	# Baseline for the first street course; a saved user setup still wins below.
	if track_key.get_base_dir().get_file() == "surfers_paradise":
		preload("res://game/vehicle/aero_model.gd").apply(sim.p,"road",14.0,14.0)
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
	return physics_ready and player_state != null and player_state.session != null and player_state.session.session_type in [player_state.session.SessionType.PRACTICE,player_state.session.SessionType.QUALIFYING,player_state.session.SessionType.PRIVATE_TESTING] and player_state.pit_stall_state == player_state.StallState.STOPPED and Vector2(sim.u,sim.v).length() < 0.5

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
		drive_step(delta, inputs.x, inputs.y, inputs.z, wheel_input.steering_from_wheel)

func drive_step(delta: float, throttle_input: float, brake_input: float, steering: float, direct_wheel_steering := false) -> void:
	if not physics_ready:
		return
	if get_meta("retired",false):
		return
	sim.direct_steering = direct_wheel_steering
	if player_state.punctured or player_state.limp_required:
		var limp_speed := preload("res://game/race/incident_rules.gd").LIMP_SPEED_MPS
		if absf(speed_mps) > limp_speed:
			throttle_input = 0.0
			brake_input = maxf(brake_input,clampf((absf(speed_mps)-limp_speed)*.08,0.0,.5))
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
	sim.dirty_air_target = Slipstream.sample(self,true) if human_controlled and dirty_air_enabled else 0.0
	if _suspension_owns_support():
		_sample_suspension_road(delta)
	var normal := suspension_normal if _suspension_owns_support() else (get_floor_normal() if is_on_floor() else Vector3.UP)
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
	var grounded: bool = sim.suspension.has_support() if _suspension_owns_support() else is_on_floor()
	# Normal + tangent gravity must still sum to world-down while airborne;
	# keeping only the bank-normal component would make freefall drift uphill.
	var plane_gravity: bool = grounded or _suspension_owns_support()
	var gravity_components := Vector3(gravity.dot(forward) if plane_gravity else 0, gravity.dot(left) if plane_gravity else 0, maxf(0,normal.dot(Vector3.UP))*9.81)
	var cap: float = track_data.speed_limit_kph/3.6 if player_state.is_in_pit_speed_zone else INF
	sim.advance(delta,throttle_input,brake_input,steering,gravity_components.x,
		gravity_components.y,gravity_components.z,grounded,grip,cap)
	var road_basis_before_yaw := _suspension_world_road_basis(normal)
	rotate_y(sim.heading_change)
	if _suspension_owns_support():
		previous_suspension_road_basis = _suspension_world_road_basis(normal)
		_transport_suspension_body(road_basis_before_yaw,previous_suspension_road_basis)
	forward = (-global_basis.z).slide(normal).normalized()
	left = normal.cross(forward).normalized()
	_update_suspension_collision()
	var vertical_fall := velocity.y-9.81*delta
	velocity = forward*sim.u+left*sim.v
	if _suspension_owns_support():
		velocity += normal*(sim.suspension.heave_delta_m/maxf(delta,.0001))
	elif not is_on_floor():
		velocity.y = vertical_fall
	var previous := global_position
	var expected := Vector2(sim.u,sim.v).length()
	var hit_static_wall := _move_with_car_contacts(delta)
	if _suspension_owns_support() and is_on_floor() and sim.suspension.heave_velocity_mps < 0:
		# Chassis bottoming is a collision backstop, not the regular wheel support.
		sim.suspension.heave_velocity_mps = 0.0
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
	var normal := suspension_normal if _suspension_owns_support() else (get_floor_normal() if is_on_floor() else Vector3.UP)
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
	_update_support_mode()
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
