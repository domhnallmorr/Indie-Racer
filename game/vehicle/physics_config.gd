extends RefCounted
## Strict loading: missing/nonphysical values stop player physics rather than use silent defaults.
var values: Dictionary = {}
var errors: Array[String] = []
const NUMERIC = {
	"assists": ["assistance_strength","steering_response_s","corner_grip_fraction","steering_range_multiplier","yaw_stability_rate_s","sideslip_damping_rate_s","traction_slip_limit","braking_slip_limit"],
	"chassis": ["mass_kg","fuel_capacity_gal","fuel_density_kg_l","fuel_range_laps","fuel_reference_lap_m","wheelbase_m","front_weight_fraction","cg_height_m","yaw_inertia_kgm2","brake_force_n","front_brake_bias","steering_lock_deg","high_speed_lock_deg","steering_reduction_speed_mps","steering_rate_deg_s","surface_step_m"],
	"tires": ["front_radius_m","rear_radius_m","front_cornering_stiffness_n_rad","rear_cornering_stiffness_n_rad","longitudinal_stiffness_n","reference_load_n","load_stiffness_exponent","friction_coefficient","grass_grip_multiplier","rolling_resistance","front_axle_inertia_kgm2","rear_axle_inertia_kgm2","slip_reference_speed_mps"],
	"engine": ["idle_rpm","redline_rpm","inertia_kgm2","throttle_rate_s","idle_control_gain","idle_control_max_nm"],
	"gearbox": ["reverse_ratio","final_drive","efficiency","shift_time_s","automatic_upshift_rpm","automatic_downshift_rpm","launch_rpm","clutch_capacity_nm","clutch_stiffness_nm_s","clutch_engagement_rate_s","direction_change_max_mps","reverse_limit_kph"],
	"aero": ["air_density_kg_m3","drag_area_m2","downforce_area_m2","front_downforce_fraction"]
}

func load_directory(directory: String) -> bool:
	var files := {}
	for section in NUMERIC:
		files[section] = directory.path_join(section+".cfg")
	return load_components(files)

func load_components(files: Dictionary) -> bool:
	values.clear()
	errors.clear()
	for section in NUMERIC:
		var config := ConfigFile.new()
		var path: String = files.get(section, "")
		if config.load(path) != OK:
			errors.append("Cannot read "+path)
			continue
		if config.get_value("meta","schema_version",0) != 1:
			errors.append("Unsupported schema in "+path)
		for key in NUMERIC[section]:
			var value = config.get_value(section,key,null)
			if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0:
				errors.append("Invalid/missing "+section+"."+key)
			else:
				values[key] = float(value)
		if section == "engine":
			values["torque_curve"] = config.get_value(section,"torque_curve",[])
		if section == "gearbox":
			values["forward_ratios"] = config.get_value(section,"forward_ratios",[])
	if not errors.is_empty():
		return false
	for key in values:
		if values[key] is float and values[key] == 0 and key not in ["assistance_strength","cg_height_m","surface_step_m","drag_area_m2","downforce_area_m2","rolling_resistance"]:
			errors.append(key+" must be positive")
	for key in ["front_weight_fraction","front_brake_bias","front_downforce_fraction","efficiency"]:
		if values[key] <= 0 or values[key] >= 1:
			errors.append(key+" must be between 0 and 1")
	if values.assistance_strength > 1 or values.corner_grip_fraction > 1 or values.traction_slip_limit >= 1 or values.braking_slip_limit >= 1:
		errors.append("Assistance strength/grip fraction must be <=1; slip limits must be <1")
	var ratios = values.forward_ratios
	if not ratios is Array or ratios.size() != 6:
		errors.append("Exactly six forward ratios required")
	else:
		var previous := INF
		for ratio in ratios:
			if not (ratio is float or ratio is int) or not is_finite(float(ratio)) or ratio <= 0 or ratio >= previous:
				errors.append("Ratios must be positive, finite and decreasing")
				break
			previous = ratio
	var curve = values.torque_curve
	if not curve is Array or curve.size() < 2:
		errors.append("Torque curve requires at least two rows")
	else:
		var previous := -1.0
		for row in curve:
			if not row is Vector3 or not row.is_finite() or row.x <= previous or row.y > 0 or row.z < 0:
				errors.append("Torque rows require increasing RPM, nonpositive coast, nonnegative full torque")
				break
			previous = row.x
		if curve[0] is Vector3 and curve[-1] is Vector3 and (curve[0].x > values.idle_rpm or curve[-1].x < values.redline_rpm):
			errors.append("Torque curve must cover idle through redline")
	if not (values.idle_rpm < values.launch_rpm and values.launch_rpm < values.automatic_downshift_rpm and values.automatic_downshift_rpm < values.automatic_upshift_rpm and values.automatic_upshift_rpm < values.redline_rpm):
		errors.append("RPM thresholds must increase: idle, launch, downshift, upshift, redline")
	if values.surface_step_m > .2 or values.high_speed_lock_deg > values.steering_lock_deg or values.steering_lock_deg >= 60:
		errors.append("Invalid step height or steering limits")
	return errors.is_empty()
