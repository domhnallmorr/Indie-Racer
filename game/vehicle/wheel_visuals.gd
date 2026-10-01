extends Node
## Shared by player and AI: signed road-speed rolling about each hub's axle.
var vehicle: Node3D
var wheels: Array[Dictionary] = []
static var branding: StandardMaterial3D

func _ready() -> void:
	vehicle = get_parent()
	if branding == null:
		branding = StandardMaterial3D.new()
		branding.albedo_texture = preload("res://content/vehicles/open_wheel/liveries/tyre_firestone.png")
		branding.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		branding.alpha_scissor_threshold = .3
		branding.roughness = 1.0
		branding.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for axle in ["Front", "Rear"]:
		for side in ["Left", "Right"]:
			var wheel := vehicle.get_node("Visual").find_child("Wheel" + axle + side, true, false) as MeshInstance3D
			if wheel == null:
				continue
			var bounds := wheel.mesh.get_aabb()
			var radius := bounds.size.y * .5
			wheels.append({"node":wheel, "basis":wheel.basis, "radius":radius, "angle":0.0})
			for face in [-1.0, 1.0]:
				var marking := MeshInstance3D.new()
				marking.name = "FirestoneInner" if (face > 0) == (side == "Left") else "FirestoneOuter"
				var quad := QuadMesh.new()
				quad.size = Vector2.ONE * radius * 2.0
				marking.mesh = quad
				marking.material_override = branding
				marking.position.x = (bounds.end.x if face > 0 else bounds.position.x) + face * .0025
				marking.rotation.y = face * PI / 2.0
				marking.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				wheel.add_child(marking)

func _process(delta: float) -> void:
	advance_distance(float(vehicle.get("speed_mps")) * delta)

func advance_distance(distance: float) -> void:
	for wheel in wheels:
		wheel.angle = fposmod(wheel.angle - distance / wheel.radius, TAU)
		wheel.node.basis = wheel.basis * Basis(Vector3.RIGHT, wheel.angle)
