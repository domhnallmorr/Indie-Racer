extends Node3D
const TrackSessionData = preload("res://game/race/track_session_data.gd")
@export_file("*.json") var track_session_file := "res://content/tracks/mile_oval/session.json"
var track_data = TrackSessionData.new()
@export var ai_enabled := true
var ai_cars: Array[Node3D] = []
var lap_timing: Node
@onready var session = $Session
@onready var player: Node3D = $DisplayCar
@onready var player_state = $DisplayCar/PlayerState

func _ready() -> void:
	var error: Error = track_data.load_config(track_session_file)
	if error != OK:
		push_error("Cannot start practice: invalid track session file: " + track_session_file)
		$HUD/Panel/Label.text = "Practice could not start. Check the track session file."
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
	for ai_car in ai_cars:
		var driver = ai_car.get_node("Driver")
		$HUD/Panel/Label.text += "\n%s: %s  %.0f km/h" % [ai_car.name, ["IN BOX","PIT EXIT","RACING"][driver.mode], absf(ai_car.speed_mps)*3.6]
	if not ai_cars.is_empty():
		$HUD/Panel/Label.text += "\n6: follow blue AI   7: follow yellow AI"
	$HUD/Panel/Label.text += "\n8: physics debug   9: practice timing   F10: wheel setup"
	$HUD/Panel/Label.text += "\nF11: telemetry " + ("RECORDING" if player.telemetry.file != null else "off")
	$HUD/Panel/Label.text += "\n%s  Gear %s  %.0f RPM" % ["AUTO" if player.sim.automatic else "MANUAL",player.gear_text,player.engine_rpm]

func _spawn_ai() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://content/tracks/mile_oval/ai/race_line.json"))
	if not data is Dictionary or not data.get("points") is Array or data.points.size() < 3 or track_data.pit_boxes.size() < 3:
		push_error("AI needs a valid race line and three pit boxes")
		return
	for i in range(2):
		var vehicle = load("res://content/vehicles/open_wheel/scenes/vehicle.tscn").instantiate()
		vehicle.name = "AI_Blue" if i == 0 else "AI_Yellow"
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
					paint.albedo_color = Color(.025,.22,.85) if i == 0 else Color(.95,.7,.025)
					mesh.set_surface_override_material(surface,paint)
		var driver := Node.new()
		driver.name = "Driver"
		driver.set_script(load("res://game/ai/oval_driver.gd"))
		vehicle.add_child(driver)
		driver.configure(vehicle,data,10.0 if i == 0 else 4.0)
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
