extends PanelContainer
var player: Node
@export var embedded := false
var shell: Control
var label: Label
var refresh_time := 0.0

func _ready() -> void:
	if not embedded:
		set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		offset_left = 18
		offset_top = -230
		offset_bottom = -18
	else:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.02,.035,.05,.94)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel",style)
	label = Label.new()
	label.add_theme_font_size_override("font_size",14)
	add_child(label)
	if not embedded:
		hide()

func _unhandled_input(event: InputEvent) -> void:
	if embedded:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_8:
		visible = not visible

func _process(delta: float) -> void:
	refresh_time += delta
	if not visible or refresh_time < .1:
		return
	refresh_time = 0
	var sim = player.sim
	label.text = "PLAYER PHYSICS\n\n%s  %s  |  %.0f RPM  |  %s\nFuel %.1f gal / %.1f L   mass %.0f kg\nForward %.1f / lateral %.1f m/s   yaw %.1f °/s\nSlip angle F %.1f° / R %.1f°   steer %.1f°\nWheel slip F %.0f%% / R %.0f%%\nGrip usage F %.0f%% / R %.0f%%\nAxle load F %.0f / R %.0f N\nDownforce %.0f N   drag %.0f N   clutch %.0f%%\n\nPlayer telemetry: %s (F11)" % ["AUTO" if sim.automatic else "MANUAL",player.gear_text,player.engine_rpm,player.surface_name,player.player_state.fuel_gal,player.player_state.fuel_litres(),sim.vehicle_mass_kg,sim.u,sim.v,rad_to_deg(sim.yaw_rate),rad_to_deg(sim.front_slip_angle),rad_to_deg(sim.rear_slip_angle),rad_to_deg(sim.steer),sim.front_slip_ratio*100,sim.rear_slip_ratio*100,sim.front_usage*100,sim.rear_usage*100,sim.front_load,sim.rear_load,sim.downforce_n,sim.drag_n,sim.clutch*100,"RECORDING" if player.telemetry.file != null else "off"]
