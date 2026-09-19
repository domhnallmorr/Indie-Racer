extends Node3D
## Visual cockpit only. Mirror cameras share the main world; no vehicle physics.
const DASH = preload("res://game/ui/cockpit_dashboard.gd")
var camera: Camera3D
var interior: Node3D
var mirror_views: Array[SubViewport] = []
var active := false
var rear_cameras: Array[Camera3D] = []
var rear_local_poses: Array[Transform3D] = []
var dashboard_view: SubViewport
var virtual_mirror: PanelContainer

func _ready() -> void:
	position = get_parent().get_node("Visual").get_meta("cockpit_offset",Vector3.ZERO)
	interior = load("res://content/vehicles/open_wheel/models/cockpit.glb").instantiate()
	add_child(interior)
	var exterior_nose = get_parent().get_node("Visual").find_child("Nose",true,false)
	for mesh in interior.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 4
		if mesh.name.begins_with("Mirror"):
			mesh.hide()
		if mesh.name.begins_with("Instrument"):
			mesh.scale.x *= get_parent().get_node("Visual").get_meta("dashboard_width_scale",1.0)
			mesh.scale.y *= get_parent().get_node("Visual").get_meta("dashboard_width_scale",1.0)
			mesh.position.z += get_parent().get_node("Visual").get_meta("dashboard_rearward_offset",0.0)
		if exterior_nose != null:
			for surface in range(mesh.mesh.get_surface_count()):
				var original = mesh.get_active_material(surface)
				if original != null and original.resource_name == "CockpitRed":
					var paint = original.duplicate()
					paint.albedo_color = exterior_nose.get_active_material(0).albedo_color
					mesh.set_surface_override_material(surface,paint)
	# Hide the exterior driver and small placeholder cockpit parts only from this camera.
	for mesh in get_parent().get_node("Visual").find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 2
		if mesh.name.begins_with("Driver") or mesh.name.begins_with("Helmet") or mesh.name.begins_with("Mirror") or mesh.name.begins_with("SteeringWheel") or mesh.name.begins_with("CockpitRim"):
			mesh.layers = 16
	camera = Camera3D.new()
	camera.name = "DriverEye"
	camera.position = Vector3(0, .84, .28)
	camera.rotation_degrees.x = -6
	camera.fov = 65
	camera.near = .025
	camera.far = 3000
	camera.cull_mask = 7
	add_child(camera)
	var display := SubViewport.new()
	dashboard_view = display
	display.size = Vector2i(640,320)
	display.disable_3d = true
	display.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(display)
	var dashboard := Control.new()
	dashboard.set_script(DASH)
	dashboard.player = get_parent()
	display.add_child(dashboard)
	_surface("Dashboard", Vector3(0,.59,-.242), Vector2(.44,.22), display, false)
	var mirror := SubViewport.new()
	mirror.name = "VirtualMirrorView"
	mirror.size = Vector2i(960, 180)
	mirror.world_3d = get_viewport().world_3d
	# Only the main camera listens; the mirror must not duplicate spatial audio.
	mirror.audio_listener_enable_3d = false
	mirror.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(mirror)
	mirror_views.append(mirror)
	var rear := Camera3D.new()
	rear.name = "VirtualMirrorCamera"
	rear.position = Vector3(0, .90, .28)
	rear.rotation.y = PI
	# A wide horizontal field of view, independent of cockpit seat/FOV changes.
	rear.keep_aspect = Camera3D.KEEP_WIDTH
	rear.fov = 100
	rear.near = .08
	rear.far = 1500
	rear.cull_mask = 1
	mirror.add_child(rear)
	rear_cameras.append(rear)
	rear_local_poses.append(rear.transform)
	rear.global_transform = global_transform * rear.transform
	rear.current = true
	_add_virtual_mirror(mirror)
	activate()

func _add_virtual_mirror(view: SubViewport) -> void:
	var overlay := CanvasLayer.new()
	overlay.name = "VirtualMirrorOverlay"
	overlay.layer = -1 # Below the race menus and HUD, above the 3D world.
	add_child(overlay)
	virtual_mirror = PanelContainer.new()
	virtual_mirror.name = "VirtualMirror"
	overlay.add_child(virtual_mirror)
	virtual_mirror.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	virtual_mirror.offset_left = -246
	virtual_mirror.offset_right = 246
	virtual_mirror.offset_top = 18
	virtual_mirror.offset_bottom = 120
	virtual_mirror.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.015, 0.015, 0.018)
	frame.set_corner_radius_all(10)
	frame.set_content_margin_all(6)
	virtual_mirror.add_theme_stylebox_override("panel", frame)
	var image := TextureRect.new()
	image.texture = view.get_texture()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.flip_h = true
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	virtual_mirror.add_child(image)

func _process(_delta: float) -> void:
	# SubViewport cameras do not inherit the car transform. Follow spawn/repositioning.
	for i in range(rear_cameras.size()):
		rear_cameras[i].global_transform = global_transform * rear_local_poses[i]

func _surface(label: String, pos: Vector3, dimensions: Vector2, viewport: SubViewport, flip: bool) -> void:
	if label == "Dashboard":
		dimensions *= get_parent().get_node("Visual").get_meta("dashboard_width_scale",1.0)
		pos.z += get_parent().get_node("Visual").get_meta("dashboard_rearward_offset",0.0)
	var panel := MeshInstance3D.new()
	panel.name = label
	var quad := QuadMesh.new()
	quad.size = dimensions
	panel.mesh = quad
	panel.position = pos
	panel.layers = 4
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = viewport.get_texture()
	if flip:
		material.uv1_scale.x = -1
		material.uv1_offset.x = 1
	panel.material_override = material
	add_child(panel)

func activate() -> void:
	active = true
	virtual_mirror.show()
	camera.make_current()
	dashboard_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for mirror in mirror_views:
		mirror.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func deactivate() -> void:
	active = false
	virtual_mirror.hide()
	dashboard_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for mirror in mirror_views:
		mirror.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var key: Key = event.keycode
		if event.physical_keycode in [KEY_KP_ADD,KEY_KP_SUBTRACT]:
			key = event.physical_keycode
		if key == KEY_5:
			activate()
		elif key in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_6, KEY_7, KEY_T, KEY_KP_ADD, KEY_KP_SUBTRACT]:
			deactivate()
		elif active:
			match key:
				KEY_BRACKETLEFT: camera.fov = maxf(45, camera.fov - 2)
				KEY_BRACKETRIGHT: camera.fov = minf(85, camera.fov + 2)
				KEY_PAGEUP: camera.position.y = minf(.94, camera.position.y + .01)
				KEY_PAGEDOWN: camera.position.y = maxf(.77, camera.position.y - .01)
				KEY_HOME:
					camera.position.y = .84
					camera.fov = 65
