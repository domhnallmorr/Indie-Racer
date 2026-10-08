extends Node3D
## The same controls move between the physical screen and its readable close-up.
var practice: Node
var cockpit: Node3D
var player: Node
var display: SubViewport
var hardware: Node3D
var screen: MeshInstance3D
var overlay: CanvasLayer
var backdrop: ColorRect
var center: CenterContainer
var panel: PanelContainer
var home: VBoxContainer
var setup_page: VBoxContainer
var fuel_page: VBoxContainer
var wings_page: VBoxContainer
var gearing_page: VBoxContainer
var gearing: VBoxContainer
var gearing_button: Button
var roll_page: VBoxContainer
var roll: VBoxContainer
var roll_button: Button
var aero: VBoxContainer
var fuel: Label
var heading: Label
var depart: Button
var setup_button: Button
var close_button: Button
var fuel_button: Button
var wings_button: Button
var fuel_minus: Button
var focused := false

func _ready() -> void:
	player = practice.player
	cockpit = player.get_node("Cockpit")
	display = SubViewport.new()
	display.size = Vector2i(900,580)
	display.disable_3d = true
	add_child(display)
	hardware = Node3D.new()
	cockpit.add_child(hardware)
	_box(Vector3(0,1.04,-1.05),Vector3(1.02,.69,.09),Color("252a30"))
	_box(Vector3(0,.56,-1.10),Vector3(.065,.35,.065),Color("535b63"))
	_box(Vector3(0,.38,-1.10),Vector3(.48,.045,.28),Color("252a30"))
	# Keep the screen below the virtual mirror and above the instruments.
	hardware.position = Vector3(0,-.10,-.35)
	screen = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(.96,.619)
	screen.mesh = quad
	screen.position = Vector3(0,1.04,-.998)
	screen.layers = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = display.get_texture()
	screen.material_override = material
	hardware.add_child(screen)
	overlay = CanvasLayer.new()
	overlay.layer = 2
	add_child(overlay)
	backdrop = ColorRect.new()
	backdrop.color = Color(0.015,0.02,0.025,.86)
	overlay.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(900,580)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("101c25")
	frame.border_color = Color("363e48")
	frame.set_border_width_all(12)
	frame.set_corner_radius_all(16)
	frame.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel",frame)
	var monitor_theme := Theme.new()
	monitor_theme.default_font_size = 18
	panel.theme = monitor_theme
	display.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",16)
	panel.add_child(layout)
	heading = Label.new()
	heading.add_theme_color_override("font_color",Color("69dacb"))
	heading.add_theme_font_size_override("font_size",28)
	layout.add_child(heading)
	home = _page(layout)
	setup_button = _button(home,"Edit Car Setup",_open_setup)
	setup_button.add_theme_font_size_override("font_size",24)
	close_button = _button(home,"Return to Cockpit",close)
	depart = _button(home,"Go to Track",_depart)
	depart.add_theme_font_size_override("font_size",24)
	setup_page = _page(layout)
	fuel_button = _button(setup_page,"Fuel Load",_open_fuel)
	wings_button = _button(setup_page,"Wings",_open_wings)
	gearing_button = _button(setup_page,"Gearing",_open_gearing)
	roll_button = _button(setup_page,"Roll Balance",_open_roll)
	_button(setup_page,"Back to Main Menu",_home)
	fuel_page = _page(layout)
	var row := HBoxContainer.new()
	fuel_page.add_child(row)
	fuel_minus = _button(row,"− 5 GAL",_fuel.bind(-5.0))
	fuel = Label.new()
	fuel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fuel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(fuel)
	_button(row,"+ 5 GAL",_fuel.bind(5.0))
	var fuel_help := Label.new()
	fuel_help.text = "Fuel load changes take effect immediately. Returning to your pit stall restores the selected load."
	fuel_page.add_child(fuel_help)
	_button(fuel_page,"Back to Car Setup",_open_setup.bind("fuel"))
	wings_page = _page(layout)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 370
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	wings_page.add_child(scroll)
	aero = preload("res://game/ui/aero_setup.gd").new()
	aero.shell = self
	aero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(aero)
	_button(wings_page,"Back to Car Setup",_open_setup.bind("wings"))
	gearing_page = _page(layout)
	var gearing_scroll := ScrollContainer.new()
	gearing_scroll.custom_minimum_size.y = 370
	gearing_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gearing_scroll.follow_focus = true
	gearing_page.add_child(gearing_scroll)
	gearing = preload("res://game/ui/gearing_setup.gd").new()
	gearing.shell = self
	gearing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gearing_scroll.add_child(gearing)
	_button(gearing_page,"Back to Car Setup",_open_setup.bind("gearing"))
	roll_page = _page(layout)
	roll = preload("res://game/ui/roll_setup.gd").new()
	roll.shell = self
	roll_page.add_child(roll)
	_button(roll_page,"Back to Car Setup",_open_setup.bind("roll"))
	var hint := Label.new()
	hint.text = "ENTER: use monitor   •   Arrows / Tab: navigate   •   ESC: back"
	hint.add_theme_font_size_override("font_size",16)
	layout.add_child(hint)
	close()

func _page(parent: Control) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation",18)
	parent.add_child(page)
	return page

func _box(pos: Vector3, dimensions: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.position = pos
	mesh.layers = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	hardware.add_child(mesh)

func _button(parent: Control, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func available() -> bool:
	var state = player.player_state
	return state != null and state.session != null and state.session.session_type in [state.session.SessionType.PRACTICE,state.session.SessionType.QUALIFYING,state.session.SessionType.PRIVATE_TESTING] and state.pit_stall_state == state.StallState.STOPPED

func _process(_delta: float) -> void:
	var usable: bool = available() and cockpit.active and player.driving_enabled
	if not usable and focused:
		close()
	hardware.visible = usable and not focused
	display.render_target_update_mode = SubViewport.UPDATE_ALWAYS if hardware.visible else SubViewport.UPDATE_DISABLED
	if not usable:
		return
	var state = player.player_state
	var title := "FUEL LOAD" if fuel_page.visible else "WINGS" if wings_page.visible else "EDIT CAR SETUP" if setup_page.visible else "PIT MONITOR"
	if gearing_page.visible:
		title = "GEARING"
	if roll_page.visible:
		title = "ROLL BALANCE"
	heading.text = state.session.display_name().to_upper() + "  /  " + title
	fuel.text = "FUEL  /  %02d GAL" % int(state.selected_fuel_gal)
	depart.disabled = state.session.status != state.session.Status.RUNNING
	depart.text = "SESSION COMPLETE" if depart.disabled else "Go to Track"

func open() -> void:
	if not available() or not cockpit.active or not player.driving_enabled:
		return
	focused = true
	backdrop.show()
	panel.reparent(center)
	center.show()
	setup_button.grab_focus()

func close() -> void:
	focused = false
	backdrop.hide()
	_home()
	if panel.get_parent() != display:
		panel.reparent(display)
	panel.position = Vector2.ZERO
	panel.size = Vector2(900,580)
	center.hide()

func _show_page(page: VBoxContainer, first: Control) -> void:
	for candidate in [home,setup_page,fuel_page,wings_page,gearing_page,roll_page]:
		candidate.visible = candidate == page
	if focused:
		first.grab_focus()

func _home() -> void:
	_show_page(home,setup_button)

func _open_setup(return_from: String = "") -> void:
	_show_page(setup_page,wings_button if return_from == "wings" else fuel_button)
	if return_from == "gearing" and focused:
		gearing_button.grab_focus()
	if return_from == "roll" and focused:
		roll_button.grab_focus()

func _open_fuel() -> void:
	_show_page(fuel_page,fuel_minus)

func _open_wings() -> void:
	_show_page(wings_page,aero.package)
	aero.refresh()

func _open_gearing() -> void:
	gearing.refresh()
	_show_page(gearing_page,gearing.final_drive.get_line_edit())

func _open_roll() -> void:
	roll.refresh()
	_show_page(roll_page,roll.front.get_line_edit())

func _fuel(amount: float) -> void:
	if available():
		player.player_state.set_selected_fuel(amount)

func _depart() -> void:
	if not available():
		return
	# Remove the monitor before releasing the stationary car.
	close()
	hardware.hide()
	player.player_state.request_departure()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and hardware.visible:
		var local_ray: Transform3D = screen.global_transform.affine_inverse()
		var origin: Vector3 = local_ray * cockpit.camera.project_ray_origin(event.position)
		var direction: Vector3 = local_ray.basis * cockpit.camera.project_ray_normal(event.position)
		if absf(direction.z) > .0001:
			var distance: float = -origin.z / direction.z
			var point := origin + direction * distance
			if distance > 0 and absf(point.x) <= .48 and absf(point.y) <= .3095:
				open()
				get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if focused and event.keycode == KEY_ESCAPE:
		if roll_page.visible:
			_open_setup("roll")
		elif gearing_page.visible:
			_open_setup("gearing")
		elif fuel_page.visible or wings_page.visible:
			_open_setup("wings" if wings_page.visible else "fuel")
		elif setup_page.visible:
			_home()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif not focused and event.keycode in [KEY_ENTER,KEY_KP_ENTER] and available() and cockpit.active and player.driving_enabled:
		open()
		get_viewport().set_input_as_handled()
