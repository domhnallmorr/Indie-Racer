@tool
extends Node3D
## Material-only override: imported mesh and physics remain intact.
var material: ShaderMaterial
func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = preload("res://content/tracks/mile_oval/surface/asphalt.gdshader")
	material.set_shader_parameter("track_origin",get_parent().global_position)
	_apply(get_parent().get_node("Geometry"))
func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and material:
		material.set_shader_parameter("track_origin",get_parent().global_position)
func _apply(node: Node) -> void:
	if node is MeshInstance3D and (str(node.name).begins_with("RacingSurface") or str(node.name).begins_with("Apron") or str(node.name).begins_with("PitLane")):
		node.material_override = material
	for child in node.get_children():
		_apply(child)
