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

func _ready() -> void:
	position = get_parent().get_node("Visual").get_meta("cockpit_offset",Vector3.ZERO)
	interior = load("res://content/vehicles/open_wheel/models/cockpit.glb").instantiate()
	add_child(interior)
	var exterior_nose = get_parent().get_node("Visual").find_child("Nose",true,false)
	for mesh in interior.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 4
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
	for side in [-1,1]:
		var mirror := SubViewport.new()
		mirror.size = Vector2i(384,160)
		mirror.world_3d = get_viewport().world_3d
		# Only the main camera listens; mirror views must not duplicate spatial audio.
		mirror.audio_listener_enable_3d = false
		mirror.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(mirror)
		mirror_views.append(mirror)
		var rear := Camera3D.new()
		rear.position = Vector3(side*.39,.68,-.42)
		rear.rotation.y = PI + side*.12
		rear.fov = 55
		rear.near = .08
		rear.far = 1500
		rear.cull_mask = 1
		mirror.add_child(rear)
		rear_cameras.append(rear)
		rear_local_poses.append(rear.transform)
		rear.global_transform = global_transform * rear.transform
		rear.current = true
		_surface("Mirror",Vector3(side*.39,.68,-.377),Vector2(.223,.093),mirror,true)
	activate()

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
	camera.make_current()
	dashboard_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for mirror in mirror_views:
		mirror.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func deactivate() -> void:
	active = false
	dashboard_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for mirror in mirror_views:
		mirror.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_5:
			activate()
		elif event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_6, KEY_7]:
			deactivate()
		elif active:
			match event.keycode:
				KEY_BRACKETLEFT: camera.fov = maxf(45, camera.fov - 2)
				KEY_BRACKETRIGHT: camera.fov = minf(85, camera.fov + 2)
				KEY_PAGEUP: camera.position.y = minf(.94, camera.position.y + .01)
				KEY_PAGEDOWN: camera.position.y = maxf(.77, camera.position.y - .01)
				KEY_HOME:
					camera.position.y = .84
					camera.fov = 65
