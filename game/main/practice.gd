extends Node3D
const TrackSessionData = preload("res://game/race/track_session_data.gd")
const Roster = preload("res://game/race/roster_data.gd")
@export_file("*.json") var roster_file := "res://content/rosters/icr2_full/manifest.json"
@export var roster_seed := -1
var active_seed := 0
var roster = Roster.new()
var ai_profiles: Dictionary = {}
@export_file("*.json") var track_session_file := "res://content/tracks/mile_oval/session.json"
var track_data = TrackSessionData.new()
@export var ai_enabled := true
@export var ai_telemetry_enabled := false
var ai_cars: Array[Node3D] = []
@export var batch_static_visuals := true
var visual_batches = preload("res://game/render/static_visual_batches.gd").new()
var lap_timing: Node
@onready var session = $Session
@onready var player: Node3D = $DisplayCar
@onready var player_state = $DisplayCar/PlayerState

func _ready() -> void:
	if batch_static_visuals:
		visual_batches.build($MileOval)
	var selection: Dictionary = get_tree().root.get_meta("roster_selection", {})
	roster_file = selection.get("file",roster_file)
	roster_seed = selection.get("seed",roster_seed)
	ai_telemetry_enabled = selection.get("ai_telemetry",ai_telemetry_enabled)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	active_seed = rng.randi_range(0,2147483647) if roster_seed < 0 else roster_seed
	var selector = preload("res://game/ui/roster_panel.gd").new()
	selector.name = "RosterPanel"
	selector.practice = self
	$HUD.add_child(selector)
	var fps := preload("res://game/ui/fps_counter.gd").new()
	fps.name = "FPSCounter"
	$HUD.add_child(fps)
	var error: Error = track_data.load_config(track_session_file)
	if error != OK:
		push_error("Cannot start practice: invalid track session file: " + track_session_file)
		$HUD/Panel/Label.text = "Practice could not start. Check the track session file."
		set_process(false)
		set_physics_process(false)
		return
	if ai_enabled and not _load_roster():
		player.driving_enabled = false
		$HUD/Panel/Label.text = "Roster could not load: "+"; ".join(roster.errors)+"\nF12: choose roster"
		set_process(false)
		set_physics_process(false)
		return
	player.global_transform = $MileOval.global_transform * track_data.pit_box_transform()
	player_state.assigned_pit_box_id = track_data.pit_boxes[0].id
	player.track_data = track_data
	player.track = $MileOval
	player.player_state = player_state
	player.driving_enabled = true
	if not player.physics_ready:
		player.driving_enabled = false
		$HUD/Panel/Label.text = "Player physics failed to load. Check physics CFG files and Output."
		set_process(false)
		return
	_update_pit_state()
	_add_limiter_end_marker()
	$InspectionCamera.focus_player()
	session.start_practice()
	if ai_enabled:
		_spawn_ai()
	lap_timing = Node.new()
	lap_timing.name = "LapTiming"
	lap_timing.set_script(load("res://game/race/lap_timing.gd"))
	add_child(lap_timing)
	lap_timing.configure($MileOval,session,[player]+ai_cars)
	var timing_panel := PanelContainer.new()
	timing_panel.name = "TimingPanel"
	timing_panel.set_script(load("res://game/ui/timing_panel.gd"))
	timing_panel.timing = lap_timing
	$HUD.add_child(timing_panel)
	var debug := PanelContainer.new()
	debug.name = "PhysicsDebug"
	debug.set_script(load("res://game/ui/physics_debug.gd"))
	debug.player = player
	$HUD.add_child(debug)
	_update_hud()

func _physics_process(_delta: float) -> void:
	_update_pit_state()

func _process(_delta: float) -> void:
	_update_hud()

func _update_pit_state() -> void:
	player_state.set_in_pit_lane(track_data.contains_pit_lane($MileOval.to_local(player.global_position)))
	player_state.is_in_pit_speed_zone = track_data.contains_speed_limit_zone($MileOval.to_local(player.global_position))

func _update_hud() -> void:
	var status_text: String = "SESSION COMPLETE" if session.status == session.Status.FINISHED else session.clock_text() + " remaining"
	var location := "PIT LANE" if player_state.is_in_pit_lane else "OUTSIDE PIT LANE"
	var limiter := "80 km/h LIMITER ON" if player_state.is_in_pit_speed_zone else "LIMITER OFF"
	$HUD/Panel/Label.text = "PRACTICE  |  %s\n%s  |  %s  |  %.0f km/h\nW: throttle   S: brake   A / D: steer\nR: reset to pit box   1–4: exterior   5: cockpit\nCockpit: [ / ] FOV   PgUp / PgDn seat   Home reset\nQ / E: shift   M: auto/manual   V: reverse   N: neutral" % [status_text, location, limiter, absf(player_state.speed_mps) * 3.6]
	for ai_car in ai_cars.slice(0,4):
		var driver = ai_car.get_node("Driver")
		$HUD/Panel/Label.text += "\n%s: %s  %.0f km/h" % [ai_car.get_meta("driver_name",str(ai_car.name)), ["IN BOX","PIT EXIT","RACING"][driver.mode], absf(ai_car.speed_mps)*3.6]
	if not ai_cars.is_empty():
		$HUD/Panel/Label.text += "\n%d opponents — 9: full timing list" % ai_cars.size()
		$HUD/Panel/Label.text += "\n6 / 7: previous / next AI"
		var followed: int = $InspectionCamera.followed_ai
		if followed >= 0 and followed < ai_cars.size():
			$HUD/Panel/Label.text += "\nFollowing: "+str(ai_cars[followed].get_meta("driver_name"))
			var followed_driver = ai_cars[followed].get_node("Driver")
			if followed_driver.mode == 2:
				$HUD/Panel/Label.text += "  |  "+followed_driver.racecraft.state.replace("_"," ")
	$HUD/Panel/Label.text += "\n8: physics debug   9: practice timing   F10: wheel setup\nF12: roster"
	$HUD/Panel/Label.text += "\nF11: telemetry " + ("RECORDING" if player.telemetry.file != null else "off")
	$HUD/Panel/Label.text += "\n%s  Gear %s  %.0f RPM" % ["AUTO" if player.sim.automatic else "MANUAL",player.gear_text,player.engine_rpm]

func _load_roster() -> bool:
	if not roster.load_roster(roster_file):
		return false
	if roster.entries.size()+1 > track_data.pit_boxes.size():
		roster.errors.append("Track needs one pit box per AI plus the player")
	var profile_data: Dictionary = roster.read_json(track_session_file.get_base_dir()+"/ai/profiles.json")
	ai_profiles = profile_data.get("classes", {}) if profile_data.get("classes") is Dictionary else {}
	for entry in roster.entries:
		var profile = ai_profiles.get(entry.spec.ai_class)
		if not profile is Dictionary:
			roster.errors.append("Track has no AI profile for "+entry.spec.ai_class)
			continue
		for key in ["cornering_utilisation", "braking_utilisation", "braking_margin_m"]:
			var value = profile.get(key)
			if not (value is float or value is int) or not is_finite(float(value)) or value < 0 or (key != "braking_margin_m" and (value <= 0 or value > 1)):
				roster.errors.append("Invalid track AI profile: "+key)
		var factor = profile.get("minimum_cornering_factor",.8)
		if not (factor is float or factor is int) or not is_finite(float(factor)) or factor <= 0 or factor > 1:
			roster.errors.append("Invalid track AI profile: minimum_cornering_factor")
		for key in ["pit_cornering_utilisation","pit_minimum_cornering_factor","pit_braking_utilisation"]:
			if profile.has(key):
				var value = profile[key]
				if not (value is float or value is int) or not is_finite(float(value)) or value <= 0 or value > 1:
					roster.errors.append("Invalid track AI profile: "+key)
	return roster.errors.is_empty()

func _spawn_ai() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(track_session_file.get_base_dir()+"/ai/race_line.json"))
	if not data is Dictionary or not data.get("points") is Array or data.points.size() < 3:
		push_error("AI needs a valid race line")
		return
	var corridor_path := track_session_file.get_base_dir()+"/ai/racing_corridor.json"
	if FileAccess.file_exists(corridor_path):
		data["racing_corridor"] = JSON.parse_string(FileAccess.get_file_as_string(corridor_path))
	var use_icr2: bool = roster.data.get("ai_method", "bicycle") == "ICR2"
	data["profile_directory"] = track_session_file.get_base_dir()+"/ai/"
	for i in range(roster.entries.size()):
		var entry: Dictionary = roster.entries[i]
		var vehicle = load(entry.spec.scene).instantiate()
		vehicle.set_script(load("res://game/vehicle/icr2_car.gd" if use_icr2 else "res://game/vehicle/player_bicycle.gd"))
		vehicle.human_controlled = false
		vehicle.name = "AI_"+entry.id
		vehicle.physics_components = entry.spec.components.duplicate(true)
		vehicle.set_meta("driver_name",entry.driver_name)
		vehicle.set_meta("roster_entry",entry)
		var state := Node.new()
		state.name = "PlayerState"
		state.set_script(load("res://game/vehicle/player_state.gd"))
		vehicle.add_child(state)
		add_child(vehicle)
		vehicle.global_transform = $MileOval.global_transform * track_data.pit_box_transform(i+1)
		vehicle.track_data = track_data
		vehicle.track = $MileOval
		vehicle.player_state = state
		state.assigned_pit_box_id = track_data.pit_boxes[i+1].id
		vehicle.update_zone_state()
		for mesh in vehicle.get_node("Visual").find_children("*","MeshInstance3D",true,false):
			for surface in range(mesh.mesh.get_surface_count()):
				var original = mesh.get_active_material(surface)
				if original != null and original.resource_name == "Livery_RacingRed":
					var paint = original.duplicate()
					paint.albedo_color = Color.html(entry.colour)
					mesh.set_surface_override_material(surface,paint)
		var driver := Node.new()
		driver.name = "Driver"
		driver.set_script(load("res://game/ai/icr2_driver.gd" if use_icr2 else "res://game/ai/oval_driver.gd"))
		vehicle.add_child(driver)
		var sampled: Dictionary = roster.sample(entry,active_seed)
		driver.configure_performance(sampled,ai_profiles[entry.spec.ai_class])
		driver.configure(vehicle,data,4.0+6.0*(roster.entries.size()-1-i),ai_telemetry_enabled)
		vehicle.set_meta("sampled_ratings",sampled)
		if driver.diagnostic != null:
			var metadata := ConfigFile.new()
			metadata.set_value("roster","file",roster_file)
			metadata.set_value("roster","seed",active_seed)
			metadata.set_value("driver","entry",entry)
			metadata.set_value("driver","ratings",sampled)
			metadata.set_value("driver","track_profile",ai_profiles[entry.spec.ai_class])
			metadata.save(driver.diagnostic.get_path().get_basename()+".cfg")
		ai_cars.append(vehicle)
	for vehicle in ai_cars:
		vehicle.get_node("Driver").rivals.assign([player] + ai_cars)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and player.driving_enabled:
		player.global_transform = $MileOval.global_transform * track_data.pit_box_transform()
		player.reset_dynamics()
		player_state.speed_mps = 0
		player.get_node("Visual").basis = Basis.IDENTITY
		player.get_node("Cockpit").basis = Basis.IDENTITY
		lap_timing.invalidate(player)
		_update_pit_state()

func _add_limiter_end_marker() -> void:
	var line := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(.3,.025,10)
	line.mesh = box
	line.position = Vector3(track_data.speed_exit_x,.04,101)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2,1,0.25)
	line.material_override = material
	$MileOval.add_child(line)
	var sign := Label3D.new()
	sign.text = "END 80\nFULL SPEED"
	sign.font_size = 64
	sign.pixel_size = .012
	sign.position = Vector3(track_data.speed_exit_x,2.2,94.5)
	sign.rotation.y = -PI / 2
	$MileOval.add_child(sign)
