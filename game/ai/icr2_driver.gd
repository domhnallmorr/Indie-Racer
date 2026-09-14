extends "res://game/ai/oval_driver.gd"
## ICR2-inspired reference speeds plus collision-aware kinematic path following.
## Reuses departure geometry, merge checks and progress tracking, not tyre physics.
var reference_speeds := PackedFloat64Array()
var pace_scale := 1.0
var profile_ready := false
var pit_profile: Dictionary = {}
var profile_error := ""
var profile_speed := 0.0
var requested_speed := 0.0
var current_line_error := 0.0

func configure(vehicle: Node3D, race_data: Dictionary, delay: float, record_telemetry: bool = false) -> void:
	# Parent diagnostic columns describe pedal/tyre controls, so use our own schema.
	super.configure(vehicle,race_data,delay,false)
	# race.lp remains the clean-air pace reference.  The aligned PASS1/PASS2
	# geometry from the corridor supplies tactical alternatives while racing.
	# The reference controller's calibrated clean-air path reaches about 7.2 m
	# from centre on this 8 m car-centre corridor.  Preserve that proven margin;
	# the general bicycle driver keeps its more conservative 7 m response.
	racecraft.road_edge_speed_start_m = 8.0
	var path: String = race_data.profile_directory
	var profile = JSON.parse_string(FileAccess.get_file_as_string(path+"race.lp.json"))
	var pit = JSON.parse_string(FileAccess.get_file_as_string(path+"pit_out.lp.json"))
	if not profile is Dictionary or not pit is Dictionary:
		profile_error = "Missing ICR2 profiles"
		push_error(profile_error)
		return
	if profile.get("schema_version") != 1 or pit.get("schema_version") != 1:
		profile_error = "Unsupported ICR2 profile schema"
		push_error(profile_error)
		return
	for key in ["departure_kph", "cruise_kph", "merge_acceleration_m"]:
		var value = pit.get(key)
		if not (value is float or value is int) or not is_finite(value) or value <= 0:
			profile_error = "Invalid pit-out profile: "+key
			push_error(profile_error)
			return
	if profile.get("reference_points") != race_data.points or profile.get("speed_mps",[]).size() != race.size():
		profile_error = "ICR2 profile is stale; rebuild it for the current racing line"
		push_error(profile_error)
		return
	for value in profile.speed_mps:
		if not (value is float or value is int) or not is_finite(value) or value <= 0:
			profile_error = "Invalid ICR2 reference speed"
			push_error(profile_error)
			return
		reference_speeds.append(value)
	pit_profile = pit
	var entry: Dictionary = car.get_meta("roster_entry")
	if float(profile.get("reference_lap_s",0)) <= 0 or float(entry.get("icr2_lap_s",0)) <= 0:
		profile_error = "ICR2 lap targets must be positive"
		push_error(profile_error)
		return
	pace_scale = profile.reference_lap_s/float(entry.get("icr2_lap_s",profile.reference_lap_s))
	profile_ready = true
	if record_telemetry:
		DirAccess.make_dir_recursive_absolute("user://telemetry")
		diagnostic = FileAccess.open("user://telemetry/icr2_"+str(car.name)+"_"+str(Time.get_ticks_msec())+".csv",FileAccess.WRITE)
		if diagnostic != null:
			diagnostic.store_line("time_s,mode,index,x_m,y_m,z_m,speed_kph,profile_kph,target_kph,line_error_m,reason,racecraft,lane,target_lane,opponent,passes")

func _physics_process(delta: float) -> void:
	if car == null or not profile_ready:
		return
	elapsed += delta
	if mode == Mode.WAITING:
		if elapsed >= release_delay and _departure_clear():
			mode = Mode.PIT_EXIT
		else:
			car.reference_step(delta,0,0)
			return
	var position: Vector3 = car.track.to_local(car.global_position)
	_update_index(position)
	racecraft.update(self,delta)
	var points := race if mode == Mode.RACING else route
	var closest := Geometry3D.get_closest_point_to_segment(position,points[index],points[(index+1)%points.size()])
	var origin_offset := closest.distance_to(points[index])
	# race.lp supplies the common longitudinal speed coordinate, but its PASS1/
	# PASS2 alternatives are intentionally laterally displaced.  Measure the
	# existing off-line safety correction from the selected blended path instead
	# of treating a correctly held passing line as a tracking failure.
	var intended_point: Vector3 = racecraft.ahead(self,origin_offset) if mode == Mode.RACING else closest
	current_line_error = Vector2(position.x-intended_point.x,position.z-intended_point.z).length()
	var lookahead := clampf(4.0+car.speed_mps*.22,5,22)
	var target_point: Vector3 = racecraft.ahead(self,origin_offset+lookahead) if mode == Mode.RACING else _ahead(origin_offset+lookahead)
	var target: Vector3 = car.track.to_global(target_point)
	var offset: Vector3 = car.global_basis.inverse()*(target-car.global_position)
	offset.y = 0
	var curvature := -2.0*offset.x/maxf(offset.length_squared(),1)
	profile_speed = _pit_exit_speed() if mode == Mode.PIT_EXIT else _planned_speed()
	if mode == Mode.RACING:
		max_line_error_m = maxf(max_line_error_m,current_line_error)
	if current_line_error > 3:
		profile_speed *= clampf(1-(current_line_error-3)*.12,.3,1)
	desired_speed_kph = profile_speed*3.6
	requested_speed = _traffic_speed(profile_speed)
	if mode == Mode.PIT_EXIT and not merge_blocker.is_empty():
		traffic_reason = "merge_yield_"+merge_blocker
	car.reference_step(delta,requested_speed,curvature)
	if diagnostic != null:
		log_elapsed += delta
		log_flush_elapsed += delta
		if log_elapsed >= .1:
			log_elapsed = 0
			diagnostic.store_line("%f,%d,%d,%f,%f,%f,%f,%f,%f,%f,%s,%s,%f,%f,%s,%d" % [elapsed,mode,index,position.x,position.y,position.z,car.speed_mps*3.6,profile_speed*3.6,requested_speed*3.6,current_line_error,traffic_reason,racecraft.state,racecraft.lane,racecraft.target_lane,str(racecraft.opponent.name) if is_instance_valid(racecraft.opponent) else "",racecraft.passes])
		if log_flush_elapsed >= 1:
			diagnostic.flush()
			log_flush_elapsed = 0

func _planned_speed() -> float:
	if mode == Mode.PIT_EXIT:
		# Authored route phases; acceleration/braking limits make continuous ramps.
		var remaining := route_distances[-1]-route_distances[index]
		var join_speed := reference_speeds[route_join_index]*pace_scale
		var cruise: float = pit_profile.cruise_kph/3.6
		var request := lerpf(cruise,join_speed,clampf(1-remaining/float(pit_profile.merge_acceleration_m),0,1))
		if index < 21:
			request = minf(request,float(pit_profile.departure_kph)/3.6)
		return request
	var position: Vector3 = car.track.to_local(car.global_position)
	var segment := race[(index+1)%race.size()]-race[index]
	var fraction := clampf((position-race[index]).dot(segment)/maxf(segment.length_squared(),.001),0,1)
	var clean_air_speed := lerpf(reference_speeds[index],reference_speeds[(index+1)%race.size()],fraction)*pace_scale
	return clean_air_speed*racecraft.speed_factor()
