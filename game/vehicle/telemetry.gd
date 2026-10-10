extends RefCounted
## One row per player physics tick, in metric units. Flush periodically and on stop.
var file: FileAccess
var path := ""
var elapsed := 0.0
var flush_elapsed := 0.0

func start(player: Node, directory: String = "user://telemetry") -> Error:
	if file != null:
		return OK
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	path = directory + "/practice_" + Time.get_datetime_string_from_system().replace(":", "-") + "_" + str(Time.get_ticks_msec()) + ".csv"
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	elapsed = 0
	flush_elapsed = 0
	var header := "time_s,dt_s,track_x_m,track_y_m,track_z_m,heading_deg,throttle_input,brake_input,steering_input,steer_deg,speed_kph,u_mps,v_left_mps,yaw_deg_s,rpm,gear,grounded,normal_x,normal_y,normal_z,gravity_forward_mps2,gravity_left_mps2,normal_gravity_mps2,grip_scale,surface,pit_limit,front_slip_deg,rear_slip_deg,front_slip_ratio,rear_slip_ratio,front_usage,rear_usage,front_load_n,rear_load_n,downforce_n,drag_n,collision_count,actual_x_mps,actual_y_mps,actual_z_mps,wheel_enabled,setup_open,fuel_gal,fuel_l,vehicle_mass_kg,wall_closing_mps,wall_delta_v_mps,wall_impulse_ns,wall_normal_energy_j"
	header += ",aero_body_package,front_wing_deg,rear_wing_deg,airspeed_mps,front_downforce_n,rear_downforce_n,drag_area_m2,downforce_area_m2,front_aero_fraction,coefficient_area_scale,wind_forward_mps,wind_left_mps"
	header += ",banking_load_n"
	header += ",final_drive,gear_ratio_1,gear_ratio_2,gear_ratio_3,gear_ratio_4,gear_ratio_5,gear_ratio_6"
	header += ",slipstream_target,slipstream_strength,slipstream_drag_reduction"
	header += ",dirty_air_target,dirty_air_strength"
	header += ",assistance_strength,steering_assistance,stability_assistance,traction_control,anti_lock_brakes"
	header += ",longitudinal_accel_mps2,load_transfer_accel_mps2,load_transfer_n"
	header += ",assisted_steering_lock_deg"
	for corner in ["fl","fr","rl","rr"]:
		header += ","+corner+"_load_n,"+corner+"_peak_n,"+corner+"_usage,"+corner+"_demand"
	header += ",front_roll_stiffness_fraction,lateral_contact_accel_mps2,front_lateral_transfer_n,rear_lateral_transfer_n"
	header += ",automatic_gears,direct_wheel_steering,clutch_engagement,clutch_torque_min_nm,clutch_torque_max_nm,engine_opening,integration_steps"
	header += ",handling_model"
	header += ",front_left_omega_rad_s,front_right_omega_rad_s"
	header += ",rear_stagger_mm,rear_stagger_active,rear_left_radius_m,rear_right_radius_m,rear_track_yaw_moment_nm"
	for corner in ["fl","fr","rl","rr"]:
		header += ","+corner+"_slip_ratio,"+corner+"_slip_deg,"+corner+"_fx_n,"+corner+"_fy_n"
	header += ",rl_yaw_moment_nm,rr_yaw_moment_nm"
	header += ",rear_differential_active,rear_left_omega_rad_s,rear_right_omega_rad_s,rear_diff_drive_lock,rear_diff_coast_lock,rear_diff_preload_nm,rear_diff_drive_phase,rear_diff_capacity_nm,rear_coupling_torque_nm,rear_coupling_dissipation_j"
	header += ",dynamic_roll_pitch,body_roll_deg,body_pitch_deg,body_roll_rate_deg_s,body_pitch_rate_deg_s,roll_reaction_nm,pitch_reaction_nm"
	header += ",wheel_travel_active,heave_velocity_mps,road_normal_accel_mps2"
	for corner in ["fl","fr","rl","rr"]:
		header += ","+corner+"_compression_m,"+corner+"_compression_rate_mps,"+corner+"_contact,"+corner+"_bump_stop_n"
	file.store_csv_line(PackedStringArray(header.split(",")))
	var metadata := ConfigFile.new()
	metadata.set_value("run", "physics", player.parameters.values)
	metadata.set_value("run", "handling_model", player.sim.handling_model_id())
	metadata.set_value("run", "tyre_load_curve", {"model":"icr2_load_polynomial_trial_v1",
		"native_load_units_per_n":player.sim.TYRE_NATIVE_LOAD_UNITS_PER_N,
		"front_load_factor":1.1,"zero_load_efficiency":player.sim.TYRE_ZERO_LOAD_EFFICIENCY,
		"linear_coefficient":2.95,"quadratic_coefficient":.0004915,"efficiency_floor":5000.0,
		"normalization":"matched_static_weight_indy_recording","si_conversion_verified":false})
	metadata.set_value("run", "integration", {"scheme":player.sim.INTEGRATION_SCHEME,
		"max_step_s":player.sim.MAX_INTEGRATION_STEP_S})
	metadata.set_value("run", "rear_differential", {"model":"bounded_clutch_hypothesis_v1","icr2_verified":false,
		"active":player.sim.rear_differential_active(),"drive_lock":player.sim.rear_diff_drive_lock,
		"coast_lock":player.sim.rear_diff_coast_lock,"preload_nm":player.sim.rear_diff_preload_nm,
		"capacity_equation":"preload + 0.5 * abs(axle_input_torque) * phase_lock_factor"})
	metadata.set_value("run", "aero_track_key", player.aero_setup_key)
	metadata.set_value("run", "suspension", player.sim.suspension.metadata())
	metadata.set_value("run", "wind_world_mps", player.wind_world_mps)
	metadata.set_value("run", "wheel_bindings", player.wheel_input.bindings)
	metadata.set_value("run", "track_transform", player.track.global_transform)
	metadata.save(path.get_basename() + ".cfg")
	print("Telemetry recording: ", ProjectSettings.globalize_path(path))
	return OK

func stop() -> void:
	if file != null:
		file.flush()
		file.close()
		file = null
		print("Telemetry saved: ", ProjectSettings.globalize_path(path))

func record(player: Node, delta: float, inputs: Vector3, normal: Vector3, gravity_components: Vector3, grip: float, grounded: bool, actual: Vector3) -> void:
	if file == null:
		return
	elapsed += delta
	flush_elapsed += delta
	var sim = player.sim
	var pos: Vector3 = player.track.to_local(player.global_position)
	var values := [elapsed, delta, pos.x, pos.y, pos.z, rad_to_deg(player.rotation.y), inputs.x, inputs.y, inputs.z, rad_to_deg(sim.steer), absf(player.speed_mps)*3.6, sim.u, sim.v, rad_to_deg(sim.yaw_rate), sim.rpm(), sim.gear, int(grounded), normal.x, normal.y, normal.z, gravity_components.x, gravity_components.y, gravity_components.z, grip, player.surface_name, int(player.player_state.is_in_pit_speed_zone), rad_to_deg(sim.front_slip_angle),rad_to_deg(sim.rear_slip_angle),sim.front_slip_ratio,sim.rear_slip_ratio,sim.front_usage,sim.rear_usage,sim.front_load,sim.rear_load,sim.downforce_n,sim.drag_n,player.get_slide_collision_count(),actual.x,actual.y,actual.z,int(player.wheel_input.enabled.button_pressed),int(player.wheel_input.panel.is_visible_in_tree()),player.player_state.fuel_gal,player.player_state.fuel_litres(),sim.vehicle_mass_kg]
	var impact: Dictionary = player.wall_impact_this_step
	for key in ["closing_speed_mps","delta_velocity_mps","normal_impulse_ns","normal_energy_j"]:
		values.append(impact.get(key,0.0))
	values.append_array([sim.p.body_package,sim.p.front_wing_deg,sim.p.rear_wing_deg,sim.airspeed_mps,sim.front_downforce_n,sim.rear_downforce_n,sim.p.drag_area_m2,sim.p.downforce_area_m2,sim.p.front_downforce_fraction,sim.p.coefficient_area_scale,sim.wind_body_mps.x,sim.wind_body_mps.y])
	values.append(sim.banking_load_n)
	values.append(sim.p.final_drive)
	values.append_array(sim.p.forward_ratios)
	values.append_array([sim.slipstream_target,sim.slipstream_strength,sim.slipstream_drag_reduction])
	values.append_array([sim.dirty_air_target,sim.dirty_air_strength])
	values.append_array([sim.p.assistance_strength,sim.p.steering_assistance,sim.p.stability_assistance,sim.p.traction_control,sim.p.anti_lock_brakes])
	values.append_array([sim.acceleration,sim.load_transfer_acceleration,sim.load_transfer_n])
	values.append(sim.assisted_steering_lock_deg)
	for i in range(4):
		values.append_array([sim.wheel_loads[i],sim.wheel_peaks[i],sim.wheel_usage[i],sim.wheel_demand[i]])
	values.append_array([sim.p.front_roll_stiffness_fraction,sim.lateral_contact_acceleration,sim.front_lateral_transfer_n,sim.rear_lateral_transfer_n])
	values.append_array([int(sim.automatic),int(sim.direct_steering),sim.clutch,sim.clutch_torque_min_nm,sim.clutch_torque_max_nm,sim.engine_opening,sim.integration_steps])
	values.append(sim.handling_model_id())
	values.append_array([sim.front_left_omega,sim.front_right_omega])
	values.append_array([0.0,0,sim.p.rear_radius_m,sim.p.rear_radius_m,sim.rear_track_yaw_moment_nm])
	for i in range(4):
		values.append_array([sim.wheel_slip_ratios[i],rad_to_deg(sim.wheel_slip_angles[i]),sim.wheel_forces[i].x,sim.wheel_forces[i].y])
	values.append_array([sim.rear_left_yaw_moment_nm,sim.rear_right_yaw_moment_nm])
	values.append_array([1,sim.rear_left_omega,sim.rear_right_omega,
		sim.rear_diff_drive_lock,sim.rear_diff_coast_lock,sim.rear_diff_preload_nm,int(sim.rear_diff_drive_phase),sim.rear_diff_capacity_nm,
		sim.rear_coupling_torque_nm,sim.rear_coupling_dissipation_j])
	values.append_array([int(sim.suspension.enabled),rad_to_deg(sim.suspension.roll),rad_to_deg(sim.suspension.pitch),
		rad_to_deg(sim.suspension.roll_rate),rad_to_deg(sim.suspension.pitch_rate),sim.suspension.roll_reaction_nm,sim.suspension.pitch_reaction_nm])
	values.append_array([int(sim.suspension.travel_active()),sim.suspension.heave_velocity_mps,sim.road_normal_acceleration])
	for i in range(4):
		values.append_array([sim.suspension.compression[i],sim.suspension.compression_rate[i],sim.suspension.contact[i],sim.suspension.bump_stop_loads[i]])
	var row := PackedStringArray()
	for value in values:
		row.append(str(value))
	file.store_csv_line(row)
	if flush_elapsed >= 1:
		file.flush()
		flush_elapsed = 0
