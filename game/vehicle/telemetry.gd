extends RefCounted
## One row per player physics tick, in metric units. Flush periodically and on stop.
var file: FileAccess
var path := ""
var elapsed := 0.0
var flush_elapsed := 0.0

func start(player: Node, directory: String = "user://telemetry") -> Error:
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	path = directory + "/practice_" + Time.get_datetime_string_from_system().replace(":", "-") + "_" + str(Time.get_ticks_msec()) + ".csv"
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	elapsed = 0
	flush_elapsed = 0
	file.store_csv_line(PackedStringArray("time_s,dt_s,track_x_m,track_y_m,track_z_m,heading_deg,throttle_input,brake_input,steering_input,steer_deg,speed_kph,u_mps,v_left_mps,yaw_deg_s,rpm,gear,grounded,normal_x,normal_y,normal_z,gravity_forward_mps2,gravity_left_mps2,normal_gravity_mps2,grip_scale,surface,pit_limit,front_slip_deg,rear_slip_deg,front_slip_ratio,rear_slip_ratio,front_usage,rear_usage,front_load_n,rear_load_n,downforce_n,drag_n,collision_count,actual_x_mps,actual_y_mps,actual_z_mps,wheel_enabled,setup_open,fuel_gal,fuel_l,vehicle_mass_kg".split(",")))
	var metadata := ConfigFile.new()
	metadata.set_value("run", "physics", player.parameters.values)
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
	var row := PackedStringArray()
	for value in values:
		row.append(str(value))
	file.store_csv_line(row)
	if flush_elapsed >= 1:
		file.flush()
		flush_elapsed = 0
