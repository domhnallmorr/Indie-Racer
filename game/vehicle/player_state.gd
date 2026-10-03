extends Node
## Shared state for future limiter, timing and pit systems. No driving logic.
signal pit_lane_changed(in_pit_lane: bool)
var is_in_pit_lane := false
var assigned_pit_box_id := ""
var is_in_pit_speed_zone := false
var speed_mps := 0.0
signal pit_stall_changed
signal fuel_changed
enum StallState { NONE, STOPPED, SERVICING, RELEASING }
var pit_stall_state: StallState = StallState.NONE
var engine_running := true
var punctured := false
var terminal_failure := false
var incident_name := ""
var limp_required := false
var car: Node3D
var session: Node
var stall_pose := Transform3D.IDENTITY
var stopped_seconds := 0.0
const US_GALLON_LITRES := 3.785411784
const FUEL_STEP_GAL := 5.0
var fuel_capacity_gal := 35.0
var fuel_density_kg_l := 0.792
var fuel_range_laps := 60.0
var fuel_reference_lap_m := 1609.344
var selected_fuel_gal := 35.0
var fuel_gal := 35.0
var fuel_per_lap_gal := 35.0/60.0
var fuel_burn_factor := 1.0
var service_remaining := 0.0
var service_initial_fuel := 0.0
var service_duration_seconds := 10.0
const REFUEL_MIN_SECONDS := 10.0
const REFUEL_MAX_SECONDS := 13.0
var refuel_rng := RandomNumberGenerator.new()

# Provisional single-set model: linear distance wear, independent of fuel load.
const TYRE_LIFE_M := 1609.344*100.0
const WORN_TYRE_GRIP := 0.92
const WORN_TYRE_PACE_PENALTY_S := 2.0
var tyre_condition := 1.0
var tyre_wear_rate := 1.0

const TYRE_WEAR_CONFIG := "res://content/vehicles/open_wheel/physics/tyre_wear.cfg"

func configure_tyre_wear(seed_value: int, config_path: String = TYRE_WEAR_CONFIG) -> void:
	tyre_wear_rate = 1.0
	var config := ConfigFile.new()
	if config.load(config_path) != OK:
		push_warning("Cannot load tyre wear config: " + config_path + "; using baseline wear")
		return
	var enabled = config.get_value("variation", "enabled", null)
	var lower = config.get_value("variation", "min_multiplier", null)
	var upper = config.get_value("variation", "max_multiplier", null)
	if not enabled is bool or not (lower is float or lower is int) or not (upper is float or upper is int):
		push_warning("Invalid tyre wear settings; using baseline wear")
		return
	if not is_finite(float(lower)) or not is_finite(float(upper)) or lower <= 0.0 or upper < lower:
		push_warning("Tyre wear bounds must be finite, positive and ordered; using baseline wear")
		return
	if not enabled:
		return
	var tyre_rng := RandomNumberGenerator.new()
	tyre_rng.seed = seed_value ^ 0x71AE
	tyre_wear_rate = tyre_rng.randf_range(float(lower),float(upper))

func tyre_wear_active() -> bool:
	return session != null and session.session_type in [session.SessionType.PRACTICE, session.SessionType.RACE]

func consume_tyre_distance(distance_m: float) -> void:
	if not tyre_wear_active() or session.status != session.Status.RUNNING:
		return
	if not is_finite(distance_m) or distance_m <= 0.0 or not engine_running or is_in_pit_lane:
		return
	if pit_stall_state in [StallState.STOPPED,StallState.SERVICING]:
		return
	tyre_condition = clampf(tyre_condition-distance_m/TYRE_LIFE_M*tyre_wear_rate,0.0,1.0)

func tyre_grip_multiplier() -> float:
	return (lerpf(WORN_TYRE_GRIP,1.0,tyre_condition) if tyre_wear_active() else 1.0)*(.65 if punctured else 1.0)

func tyre_pace_penalty_s() -> float:
	return (1.0-tyre_condition)*WORN_TYRE_PACE_PENALTY_S if tyre_wear_active() else 0.0

func replace_tyres() -> void:
	tyre_condition = 1.0
	punctured = false
	if not terminal_failure:
		limp_required = false
		incident_name = ""

func configure_fuel(values: Dictionary, capacity_override: float = 0.0) -> void:
	fuel_capacity_gal = values.fuel_capacity_gal
	fuel_density_kg_l = values.fuel_density_kg_l
	fuel_range_laps = values.fuel_range_laps
	fuel_reference_lap_m = values.fuel_reference_lap_m
	fuel_per_lap_gal = fuel_capacity_gal/fuel_range_laps
	if capacity_override > 0.0:
		fuel_capacity_gal = minf(fuel_capacity_gal,capacity_override)
	selected_fuel_gal = fuel_capacity_gal
	fuel_gal = fuel_capacity_gal
	fuel_changed.emit()

func set_selected_fuel(delta_gal: float) -> void:
	if pit_stall_state != StallState.STOPPED:
		return
	selected_fuel_gal = clampf(selected_fuel_gal+delta_gal,minf(FUEL_STEP_GAL,fuel_capacity_gal),fuel_capacity_gal)
	fuel_gal = selected_fuel_gal
	fuel_changed.emit()

func consume_distance(distance_m: float) -> void:
	consume_tyre_distance(distance_m)
	if not engine_running or distance_m <= 0.0 or fuel_gal <= 0.0:
		return
	var burn_per_m := fuel_per_lap_gal/fuel_reference_lap_m*fuel_burn_factor
	var previous := fuel_gal
	fuel_gal = maxf(0.0,fuel_gal-distance_m*burn_per_m)
	if not is_equal_approx(previous,fuel_gal):
		fuel_changed.emit()

func fuel_mass_kg() -> float:
	return fuel_gal*US_GALLON_LITRES*fuel_density_kg_l

func fuel_litres() -> float:
	return fuel_gal*US_GALLON_LITRES

func has_fuel() -> bool:
	return fuel_gal > 0.00001

func configure_stall(vehicle: Node3D, session_node: Node, pose: Transform3D) -> void:
	car = vehicle
	session = session_node
	stall_pose = pose
	if session.session_type != session.SessionType.RACE:
		park_in_stall()

func start_refuelling(duration_seconds: float = -1.0) -> void:
	service_duration_seconds = duration_seconds if duration_seconds >= REFUEL_MIN_SECONDS and duration_seconds <= REFUEL_MAX_SECONDS else refuel_rng.randf_range(REFUEL_MIN_SECONDS,REFUEL_MAX_SECONDS)
	service_remaining = service_duration_seconds
	service_initial_fuel = fuel_gal
	pit_stall_state = StallState.SERVICING

func inside_stall() -> bool:
	var offset := stall_pose.affine_inverse()*car.global_position
	return absf(offset.x) <= 1.2 and absf(offset.z) <= 2.0 and absf(offset.y) <= .6

func _physics_process(delta: float) -> void:
	if car == null or session == null:
		return
	if car.get_meta("retired",false):
		return
	if car.human_controlled and pit_stall_state == StallState.SERVICING:
		service_remaining = maxf(0.0,service_remaining-delta)
		fuel_gal = lerpf(service_initial_fuel,fuel_capacity_gal,1.0-service_remaining/service_duration_seconds)
		fuel_changed.emit()
		if service_remaining == 0.0 and session.status == session.Status.RUNNING:
			replace_tyres()
			selected_fuel_gal = fuel_capacity_gal
			pit_stall_state = StallState.STOPPED
			request_departure()
		return
	if pit_stall_state == StallState.RELEASING:
		if not inside_stall():
			pit_stall_state = StallState.NONE
			pit_stall_changed.emit()
		return
	# AI arrival is confirmed by its route driver; player arrival uses geometry.
	if not car.human_controlled or pit_stall_state != StallState.NONE or session.status != session.Status.RUNNING:
		return
	var aligned := car.global_basis.z.normalized().dot(stall_pose.basis.z.normalized()) >= cos(deg_to_rad(15))
	if inside_stall() and aligned and absf(car.speed_mps) < 1.0/3.6:
		if session.race_control != null and not session.race_control.may_service(car):
			stopped_seconds = 0.0
			return
		stopped_seconds += delta
		if stopped_seconds >= .35:
			if session.session_type == session.SessionType.RACE:
				car.reset_dynamics()
				set_engine_running(false)
				if terminal_failure:
					pit_stall_state = StallState.STOPPED
					car.set_meta("retired",true)
					car.set_meta("withdrawing",false)
					car.get_parent().lap_timing.retire(car,incident_name)
					pit_stall_changed.emit()
					return
				start_refuelling()
				stopped_seconds = 0.0
				pit_stall_changed.emit()
			else:
				park_in_stall()
	else:
		stopped_seconds = 0.0

func park_in_stall() -> void:
	if session == null or session.session_type == session.SessionType.RACE:
		return
	car.reset_dynamics()
	speed_mps = 0.0
	pit_stall_state = StallState.STOPPED
	stopped_seconds = 0.0
	set_engine_running(false)
	# Restore the setup load on each practice/qualifying arrival.
	set_selected_fuel(0.0)
	replace_tyres()
	pit_stall_changed.emit()

func set_engine_running(value: bool) -> void:
	if value and terminal_failure:
		return
	engine_running = value
	if "sim" in car:
		car.sim.set_engine_running(value)

func request_departure() -> bool:
	if terminal_failure or car.get_meta("retired",false):
		return false
	if pit_stall_state != StallState.STOPPED or session.status != session.Status.RUNNING:
		return false
	pit_stall_state = StallState.RELEASING
	set_engine_running(true)
	pit_stall_changed.emit()
	return true

func set_in_pit_lane(value: bool) -> void:
	if value == is_in_pit_lane:
		return
	is_in_pit_lane = value
	pit_lane_changed.emit(value)
